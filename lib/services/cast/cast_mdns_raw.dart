import 'dart:convert';
import 'dart:typed_data';

/// Minimal one-shot mDNS querier/parser used as a fallback to
/// `package:multicast_dns`, which on Windows can join the multicast group on a
/// virtual adapter (VPN/WARP) and silently miss real LAN devices.
///
/// We bind an ephemeral UDP port, send a plain PTR query to 224.0.0.251:5353
/// and parse the DNS response records (PTR/SRV/TXT/A) ourselves.
class RawMdns {
  static const serviceName = '_googlecast._tcp.local';
  static const address = '224.0.0.251';
  static const port = 5353;

  /// Pure DNS decoder - unit-testable without sockets.
  static MdnsRecords parse(Uint8List bytes) {
    final r = _DnsReader(bytes);
    if (bytes.length < 12) return MdnsRecords.empty();
    final questions = r.u16At(4);
    final answers = r.u16At(6);
    final authority = r.u16At(8);
    final additional = r.u16At(10);
    r.pos = 12;
    for (var i = 0; i < questions && r.pos < bytes.length; i++) {
      r.readName();
      r.pos += 4;
    }
    final records = MdnsRecords();
    for (var i = 0;
        i < answers + authority + additional && r.pos < bytes.length;
        i++) {
      final name = r.readName();
      final type = r.u16();
      r.u16(); // class
      r.u32(); // ttl
      final len = r.u16();
      final end = r.pos + len;
      if (end > bytes.length) break;
      switch (type) {
        case 12: // PTR
          records.ptr[name] = r.readName();
        case 16: // TXT
          final parts = <String>[];
          while (r.pos < end) {
            final l = bytes[r.pos++];
            parts.add(utf8.decode(bytes.sublist(r.pos, r.pos + l),
                allowMalformed: true));
            r.pos += l;
          }
          // Each length-prefixed string is a separate `k=v` pair; keep the
          // '#' separator expected by CastDevice.parseTxt.
          records.txt[name] = parts.join('#');
        case 33: // SRV
          r.u16(); // priority
          r.u16(); // weight
          final targetPort = r.u16();
          final target = r.readName();
          records.srv[name] = SrvRecord(target, targetPort);
        case 1: // A
          if (len >= 4) {
            records.a[name] =
                '${bytes[r.pos]}.${bytes[r.pos + 1]}.${bytes[r.pos + 2]}.${bytes[r.pos + 3]}';
          }
      }
      r.pos = end;
    }
    return records;
  }

  /// DNS question: one name label sequence + QTYPE + QCLASS.
  static Uint8List query(String name) {
    final out = <int>[0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0];
    for (final label in name.split('.')) {
      final bytes = utf8.encode(label);
      out.add(bytes.length);
      out.addAll(bytes);
    }
    out.addAll([0, 0, 12, 0, 1]); // terminating label, PTR, IN
    return Uint8List.fromList(out);
  }
}

class MdnsRecords {
  final Map<String, String> ptr = {};
  final Map<String, String> txt = {};
  final Map<String, SrvRecord> srv = {};
  final Map<String, String> a = {};

  static MdnsRecords empty() => MdnsRecords();

  bool get isEmpty => ptr.isEmpty && srv.isEmpty && txt.isEmpty && a.isEmpty;

  void merge(MdnsRecords other) {
    ptr.addAll(other.ptr);
    txt.addAll(other.txt);
    srv.addAll(other.srv);
    a.addAll(other.a);
  }
}

class SrvRecord {
  const SrvRecord(this.target, this.port);
  final String target;
  final int port;
}

class _DnsReader {
  _DnsReader(this.bytes);
  final List<int> bytes;
  int pos = 0;

  int u16At(int at) => (bytes[at] << 8) | bytes[at + 1];

  int u16() {
    final v = u16At(pos);
    pos += 2;
    return v;
  }

  int u32() {
    final v = (bytes[pos] << 24) |
        (bytes[pos + 1] << 16) |
        (bytes[pos + 2] << 8) |
        bytes[pos + 3];
    pos += 4;
    return v;
  }

  String readName() {
    final labels = <String>[];
    var jumped = false;
    var jumpBack = 0;
    var guard = 0;
    while (pos < bytes.length && guard++ < 128) {
      final length = bytes[pos];
      if (length == 0) {
        pos++;
        break;
      }
      if (length & 0xc0 == 0xc0) {
        final pointer = ((length & 0x3f) << 8) | bytes[pos + 1];
        if (!jumped) {
          jumpBack = pos + 2;
          pos = pointer;
          jumped = true;
        } else {
          pos = pointer;
        }
        continue;
      }
      pos++;
      labels.add(
          utf8.decode(bytes.sublist(pos, pos + length), allowMalformed: true));
      pos += length;
    }
    if (jumped) pos = jumpBack;
    return labels.join('.');
  }
}
