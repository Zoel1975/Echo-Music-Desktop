import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'cookie_store.dart';
import 'stream_resolver.dart';

/// A linked mobile device.
@immutable
class LinkedDevice {
  const LinkedDevice({
    required this.name,
    required this.id,
    required this.linkedAt,
  });
  final String name;
  final String id;
  final int linkedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
        'linkedAt': linkedAt,
      };
  factory LinkedDevice.fromJson(Map<String, dynamic> j) => LinkedDevice(
        name: j['name']?.toString() ?? 'Device',
        id: j['id']?.toString() ?? '',
        linkedAt: (j['linkedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Real desktop counterpart of YouTube Music's "link a device" flow: the
/// desktop shows a short pairing code and hosts a LAN endpoint. The mobile app
/// sends the code plus its account/cookie info; on success the cookies are
/// imported so both devices share one signed-in session.
class DeviceLinkService {
  DeviceLinkService();

  HttpServer? _server;
  String _code = '';
  final List<LinkedDevice> _devices = [];
  static const int port = 8901;

  String get code => _code;
  bool get isListening => _server != null;
  List<LinkedDevice> get devices => List.unmodifiable(_devices);

  /// Pure: generate a 6-digit pairing code.
  static String generateCode(Random rng) =>
      List<int>.generate(6, (_) => rng.nextInt(10)).join();

  /// Pure: validate a pairing request body.
  static ({bool ok, String? deviceName, String? cookieHeader}) parsePairRequest(
    Map<String, dynamic> json,
    String expectedCode,
  ) {
    final code = json['code']?.toString() ?? '';
    if (code != expectedCode) return (ok: false, deviceName: null, cookieHeader: null);
    final name = json['deviceName']?.toString();
    final cookie = json['cookieHeader']?.toString();
    if (name == null || name.isEmpty || cookie == null || cookie.isEmpty) {
      return (ok: false, deviceName: null, cookieHeader: null);
    }
    return (ok: true, deviceName: name, cookieHeader: cookie);
  }

  Future<String> start() async {
    _code = generateCode(Random.secure());
    if (_server != null) return _code;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handle);
    } catch (e) {
      debugPrint('[device-link] server failed: $e');
    }
    return _code;
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {}
    final parsed = json == null
        ? (ok: false, deviceName: null, cookieHeader: null)
        : parsePairRequest(json, _code);

    if (parsed.ok) {
      await CookieStore.instance.importCookieHeader(parsed.cookieHeader!);
      final device = LinkedDevice(
        name: parsed.deviceName!,
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        linkedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _devices.add(device);
      await CookieStore.instance.saveAccount({
        'name': CookieStore.instance.account['name'] ?? 'YouTube Music',
        'signedIn': true,
        'linkedDevice': device.name,
      });
      StreamResolver.instance.clearCache();
    }
    request.response
      ..statusCode = parsed.ok ? 200 : 400
      ..headers.contentType = ContentType('application', 'json')
      ..write(jsonEncode({
        'ok': parsed.ok,
        if (parsed.ok) 'device': parsed.deviceName,
      }));
    await request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
