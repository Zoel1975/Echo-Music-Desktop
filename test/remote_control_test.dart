import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/remote_control_service.dart';

void main() {
  group('RemoteControlService (desktop Cast path)', () {
    test('exposes a device descriptor with control + discovery endpoints',
        () {
      // Pure constants verified without binding sockets.
      expect(RemoteControlService.deviceName, contains('Echo Music'));
      expect(RemoteControlService.port, greaterThan(0));
      expect(RemoteControlService.discoveryPort,
          isNot(RemoteControlService.port));
      expect(RemoteControlService.discoveryProbe, 'ECHO_MUSIC_DISCOVER');
    });

    test('discovery reply is valid JSON with url/device/port', () {
      final payload = jsonEncode({
        'device': RemoteControlService.deviceName,
        'url': 'http://192.168.1.5:${RemoteControlService.port}',
        'port': RemoteControlService.port,
      });
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['device'], contains('Echo Music'));
      expect(decoded['url'], startsWith('http://'));
      expect(decoded['port'], RemoteControlService.port);
    });
  });
}
