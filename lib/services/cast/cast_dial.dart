import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cast_device.dart';
import 'cast_protocol.dart';

/// DIAL/SSDP discovery - the second method YouTube/YouTube Music senders use
/// to populate their device list (alongside mDNS). Some TVs only answer one of
/// the two, so doing both gives the same list the YouTube Music Cast icon does.
class CastDial {
  const CastDial();

  static const _address = '239.255.255.250';
  static const _port = 1900;
  static const _searchTarget = 'urn:dial-multiscreen-org:service:dial:1';

  static String buildSearch() => [
        'M-SEARCH * HTTP/1.1',
        'HOST: $_address:$_port',
        'MAN: "ssdp:discover"',
        'MX: 2',
        'ST: $_searchTarget',
        '',
        '',
      ].join('\r\n');

  /// Pure: case-insensitive HTTP headers of a SSDP reply.
  static Map<String, String> parseHeaders(String raw) {
    final out = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n')).skip(1)) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      out[line.substring(0, i).trim().toLowerCase()] =
          line.substring(i + 1).trim();
    }
    return out;
  }

  /// Pure: extract a tag from UPnP device-description XML.
  static String? xmlTag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true)
        .firstMatch(xml);
    return m?.group(1)?.trim();
  }

  /// True for DIAL replies that come from a Chromecast-enabled receiver.
  /// TVs also answer with other DIAL services (e.g. Sony's own web API).
  static bool isCastReply(Map<String, String> headers) {
    final st = headers['st'] ?? '';
    if (!st.contains(_searchTarget)) return false;
    final server = (headers['server'] ?? '').toLowerCase();
    final location = (headers['location'] ?? '').toLowerCase();
    if (server.contains('chromecast')) return true;
    // Chromecast DIAL endpoints are conventionally on port 8008.
    final port = Uri.tryParse(headers['location'] ?? '')?.port;
    return port == 8008 ||
        location.contains('cast') ||
        location.contains('device-desc');
  }

  Future<List<CastDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final seen = <String, Map<String, String>>{};
      final request = buildSearch();
      for (var i = 0; i < 2; i++) {
        socket.send(
          utf8.encode(request),
          InternetAddress(_address),
          _port,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await for (final event in socket
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        if (event != RawSocketEvent.read) continue;
        final datagram = socket.receive();
        if (datagram == null) continue;
        try {
          final headers = parseHeaders(utf8.decode(datagram.data));
          if (!isCastReply(headers)) continue;
          final uri = Uri.tryParse(headers['location'] ?? '');
          final host = uri?.host ?? '';
          if (host.isEmpty) continue;
          seen[host] = headers;
        } catch (_) {
          continue;
        }
      }
      final out = <CastDevice>[];
      for (final entry in seen.entries) {
        final host = entry.key;
        // Only devices that really expose a CastV2 port belong in the picker.
        if (!await _hasCastPort(host)) continue;
        String name = host;
        String model = '';
        final location = entry.value['location'];
        if (location != null) {
          try {
            final response = await http
                .get(Uri.parse(location))
                .timeout(const Duration(seconds: 2));
            name = xmlTag(response.body, 'friendlyName') ?? name;
            model = xmlTag(response.body, 'modelName') ?? '';
          } catch (_) {}
        }
        out.add(CastDevice(
          id: entry.value['usn'] ?? host,
          name: name,
          host: host,
          port: CastProtocol.defaultPort,
          model: model,
          kind: CastDeviceKindX.fromName(name, model),
        ));
      }
      return out;
    } catch (_) {
      return <CastDevice>[];
    } finally {
      socket?.close();
    }
  }

  static Future<bool> _hasCastPort(String host) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        CastProtocol.defaultPort,
        timeout: const Duration(seconds: 1),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
