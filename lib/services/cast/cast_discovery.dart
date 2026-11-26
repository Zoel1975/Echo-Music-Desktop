import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:multicast_dns/multicast_dns.dart';

import 'cast_device.dart';
import 'cast_dial.dart';
import 'cast_mdns_raw.dart';
import 'cast_protocol.dart';

/// Discovers Google Cast receivers on the LAN, exactly like Android's
/// MediaRouter discovers routes for `CastDevicePickerSheet`.
class CastDiscovery {
  const CastDiscovery();

  /// One-shot discovery. Returns every `_googlecast._tcp` service that answers
  /// with an address (Chromecast, Android TV, Nest Hub, BRAVIA, ...).
  Future<List<CastDevice>> discover({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    // Both discovery channels used by YouTube/YouTube Music senders:
    // mDNS (_googlecast._tcp) and DIAL/SSDP. Run them together so a device that
    // answers only one of them still appears in the picker.
    final results = await Future.wait([
      discoverRaw(timeout: timeout),
      const CastDial().discover(timeout: timeout),
    ]);
    final combined = <String, CastDevice>{
      for (final device in [...results[0], ...results[1]]) device.host: device,
    }.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (combined.isNotEmpty) return combined;

    final client = MDnsClient();
    try {
      await client.start();
      final ptrs = await _collect<PtrResourceRecord>(
        client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_googlecast._tcp'),
          timeout: timeout,
        ),
        timeout,
      );
      final devices = <String, CastDevice>{};
      await Future.wait(ptrs.map((ptr) async {
        try {
          final instance = _stripLocal(ptr.domainName);
          final srvs = await _collect<SrvResourceRecord>(
            client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
              timeout: timeout,
            ),
            timeout,
          );
          final txts = await _collect<TxtResourceRecord>(
            client.lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
              timeout: timeout,
            ),
            timeout,
          );
          final txt = txts.isNotEmpty ? txts.first.text : '';
          for (final srv in srvs) {
            final target = _stripLocal(srv.target);
            final addresses = await _collect<IPAddressResourceRecord>(
              client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
                timeout: timeout,
              ),
              timeout,
            );
            for (final a in addresses) {
              final device = CastDevice.fromMdns(
                instanceName: instance,
                host: a.address.address,
                port: srv.port > 0 ? srv.port : CastProtocol.defaultPort,
                txt: txt,
              );
              devices[device.host] = device;
            }
            // Some TVs answer SRV but not A; keep the target if it is an IP.
            if (addresses.isEmpty && _isIp(target)) {
              final device = CastDevice.fromMdns(
                instanceName: instance,
                host: target,
                port: srv.port,
                txt: txt,
              );
              devices[device.host] = device;
            }
          }
        } catch (_) {
          // A single half-answering device must not hide the others.
        }
      }));
      final list = devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      return list;
    } finally {
      client.stop();
    }
  }

  /// One-shot raw mDNS query on an ephemeral socket, with follow-up queries
  /// for the SRV/TXT/A records referenced by discovered PTR records.
  Future<List<CastDevice>> discoverRaw({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    RawDatagramSocket? socket;
    try {
      // mDNS devices answer on port 5353 and only to sockets that joined the
      // group on the *LAN* interface (the machine also has WSL/Tailscale/WARP
      // adapters, which is why binding an ephemeral port saw nothing).
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        5353,
        reuseAddress: true,
        // Windows has no SO_REUSEPORT; setting it prints a Dart socket error.
        reusePort: !Platform.isWindows,
      );
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final nic in interfaces) {
        for (final addr in nic.addresses) {
          if (addr.isLoopback) continue;
          final a = addr.address;
          final lan = a.startsWith('192.168.') || a.startsWith('10.');
          if (!lan) continue;
          try {
            socket.joinMulticast(InternetAddress(RawMdns.address), nic);
            socket.setRawOption(RawSocketOption(
              RawSocketOption.levelIPv4,
              RawSocketOption.IPv4MulticastInterface,
              Uint8List.fromList(addr.rawAddress),
            ));
          } catch (_) {}
        }
      }
      final records = MdnsRecords();
      final asked = <String>{};
      void ask(String name) {
        if (!asked.add(name.toLowerCase())) return;
        socket!.send(RawMdns.query(name), InternetAddress(RawMdns.address),
            RawMdns.port);
      }

      ask(RawMdns.serviceName);
      final end = DateTime.now().add(timeout);
      await for (final event in socket
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        if (event != RawSocketEvent.read) continue;
        final datagram = socket.receive();
        if (datagram == null) continue;
        try {
          records.merge(RawMdns.parse(Uint8List.fromList(datagram.data)));
        } catch (_) {
          continue;
        }
        for (final entry in records.ptr.entries) {
          if (entry.key.toLowerCase().contains('googlecast')) {
            ask(entry.value);
            final srv = records.srv[entry.value];
            if (srv != null) ask(srv.target);
          }
        }
        if (DateTime.now().isAfter(end)) break;
      }
      return devicesFrom(records);
    } catch (_) {
      return <CastDevice>[];
    } finally {
      socket?.close();
    }
  }

  /// Convert parsed DNS records into Cast devices (pure, unit-testable).
  static List<CastDevice> devicesFrom(MdnsRecords records) {
    // Only `_googlecast._tcp` pointers count - the same socket also sees
    // AirPlay, Android TV remote and other unrelated mDNS services.
    final instances = records.ptr.entries
        .where((e) => e.key.toLowerCase().contains('googlecast'))
        .map((e) => e.value)
        .toSet();
    final out = <String, CastDevice>{};
    for (final key in instances) {
      final instance = _stripLocal(key);
      final srv = records.srv[key];
      if (srv == null) continue;
      final target = _stripLocal(srv.target);
      final host = records.a[srv.target] ??
          records.a[srv.target + '.'] ??
          (InternetAddress.tryParse(target) != null ? target : '');
      if (host.isEmpty) continue;
      final txt = records.txt[key] ?? '';
      final device = CastDevice.fromMdns(
        instanceName: instance,
        host: host,
        port: srv.port > 0 ? srv.port : CastProtocol.defaultPort,
        txt: txt,
      );
      out[device.host] = device;
    }
    return out.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<T>> _collect<T extends ResourceRecord>(
    Stream<T> stream,
    Duration timeout,
  ) async {
    final out = <T>[];
    await for (final value in stream.timeout(timeout)) {
      out.add(value);
    }
    return out;
  }

  static String _stripLocal(String name) {
    var s = name;
    if (s.endsWith('.local')) s = s.substring(0, s.length - 6);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  static bool _isIp(String s) => InternetAddress.tryParse(s) != null;
}
