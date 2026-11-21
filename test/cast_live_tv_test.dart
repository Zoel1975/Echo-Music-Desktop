import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/cast/cast_client.dart';
import 'package:Echo/services/cast/cast_device.dart';

/// Live probe against the BRAVIA TV on the LAN (not part of the normal suite).
///   flutter test test/cast_live_tv_test.dart --run-skipped
void main() {
  test('connect + LAUNCH + LOAD on real TV', () async {
    final client = CastClient();
    final device = const CastDevice(
      id: 'bravia',
      name: 'BRAVIA',
      host: '192.168.1.18',
      port: 8009,
    );
    try {
      await client.connect(device);
      // ignore: avoid_print
      print('CONNECTED transport=${client.transportId} session=${client.sessionId}');
      final res = await client.load(
        contentId: 'http://192.168.1.10:52975/audio?id=dQw4w9WgXcQ&quality=high',
        title: 'Probe Song',
        artist: 'Probe',
      );
      // ignore: avoid_print
      print('LOAD res=$res mediaSession=${client.mediaSessionId}');
      final status = await client.mediaStatus();
      // ignore: avoid_print
      print('MEDIA STATUS=$status');
      expect(client.isConnected, isTrue);
    } catch (e) {
      // ignore: avoid_print
      print('ERROR=$e transport=${client.transportId} session=${client.sessionId}');
      rethrow;
    } finally {
      await client.disconnect();
    }
  }, skip: true, timeout: const Timeout(Duration(seconds: 60)));
}
