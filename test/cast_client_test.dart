import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/cast/cast_client.dart';
import 'package:Echo/services/cast/cast_device.dart';
import 'package:Echo/services/cast/cast_protocol.dart';

/// A fake Cast receiver on loopback: a real CastV2 conversation over TCP,
/// proving connect -> launch -> load -> play/pause/seek works end-to-end.
void main() {
  late ServerSocket server;
  final received = <Map<String, dynamic>>[];

  void reply(Socket socket, String source, String namespace, Map<String, dynamic> payload) {
    final body = CastProtocol.encode(
      sourceId: source,
      destinationId: CastProtocol.senderId,
      namespace: namespace,
      payloadUtf8: jsonEncode(payload),
    );
    final frame = Uint8List(4 + body.length);
    frame[0] = (body.length >> 24) & 0xff;
    frame[1] = (body.length >> 16) & 0xff;
    frame[2] = (body.length >> 8) & 0xff;
    frame[3] = body.length & 0xff;
    frame.setAll(4, body);
    socket.add(frame);
  }

  setUpAll(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      final buffer = <int>[];
      socket.listen((chunk) {
        buffer.addAll(chunk);
        while (buffer.length >= 4) {
          final len = (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];
          if (buffer.length < 4 + len) break;
          final msg = CastProtocol.decode(buffer.sublist(4, 4 + len));
          buffer.removeRange(0, 4 + len);
          final data = msg.json;
          received.add(data);
          switch (data['type']) {
            case 'GET_STATUS'
                when msg.namespace == CastProtocol.mediaNamespace:
              reply(socket, 'transport-1', CastProtocol.mediaNamespace, {
                'type': 'MEDIA_STATUS',
                'requestId': data['requestId'],
                'status': [
                  {'mediaSessionId': 42, 'playerState': 'PLAYING'}
                ],
              });
            case 'GET_STATUS':
              reply(socket, 'receiver-0', CastProtocol.receiverNamespace, {
                'type': 'RECEIVER_STATUS',
                'requestId': data['requestId'],
                'status': {
                  'applications': [
                    {
                      'appId': CastProtocol.defaultMediaAppId,
                      'sessionId': 'session-1',
                      'transportId': 'transport-1',
                    }
                  ],
                },
              });
            case 'LOAD':
              reply(socket, 'transport-1', CastProtocol.mediaNamespace, {
                'type': 'MEDIA_STATUS',
                'requestId': data['requestId'],
                'status': [
                  {'mediaSessionId': 42, 'playerState': 'PLAYING'}
                ],
              });
            case 'PLAY':
            case 'PAUSE':
            case 'SEEK':
              reply(socket, 'transport-1', CastProtocol.mediaNamespace, {
                'type': 'MEDIA_STATUS',
                'requestId': data['requestId'],
                'status': [
                  {
                    'mediaSessionId': 42,
                    'playerState': data['type'] == 'PAUSE' ? 'PAUSED' : 'PLAYING'
                  }
                ],
              });
          }
        }
      });
    });
  });

  tearDownAll(() async {
    await server.close();
  });

  test('connects, launches and controls a Cast receiver', () async {
    final client = CastClient();
    final device = CastDevice(
      id: 'fake',
      name: 'Fake TV',
      host: '127.0.0.1',
      port: server.port,
    );
    try {
      await client.connect(device);
      expect(client.isConnected, isTrue);
      expect(client.transportId, 'transport-1');
      expect(client.sessionId, 'session-1');

      await client.load(
        contentId: 'http://192.168.1.10:52975/audio?id=abc',
        title: 'Song',
      );
      expect(client.mediaSessionId, 42);
      expect(client.playing.value, isTrue);

      await client.pause();
      expect(client.playing.value, isFalse);
      await client.play();
      expect(client.playing.value, isTrue);
      await client.seek(const Duration(seconds: 30));

      expect(received.any((m) => m['type'] == 'CONNECT'), isTrue);
      expect(received.any((m) => m['type'] == 'LOAD'), isTrue);
      expect(received.any((m) => m['type'] == 'PAUSE'), isTrue);
      expect(received.any((m) => m['type'] == 'PLAY'), isTrue);
      final seek = received.firstWhere((m) => m['type'] == 'SEEK');
      expect((seek['seekOptions'] as Map)['position'], 30.0);
    } finally {
      await client.disconnect();
    }
  }, timeout: const Timeout(Duration(seconds: 25)));
}
