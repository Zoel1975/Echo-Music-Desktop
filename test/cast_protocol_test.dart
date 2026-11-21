import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/cast/cast_device.dart';
import 'package:Echo/services/cast/cast_discovery.dart';
import 'package:Echo/services/cast/cast_mdns_raw.dart';
import 'package:Echo/services/cast/cast_protocol.dart';
import 'package:Echo/services/yt_audio_stream.dart';

void main() {
  group('CastV2 protobuf wire format', () {
    test('framed message has a big-endian length prefix', () {
      final frame = CastProtocol.frame(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastProtocol.receiverNamespace,
        payload: CastProtocol.getStatus(3),
      );
      final declared = (frame[0] << 24) | (frame[1] << 16) | (frame[2] << 8) | frame[3];
      expect(declared, frame.length - 4);
      final msg = CastProtocol.decode(frame.sublist(4));
      expect(msg.sourceId, 'sender-0');
      expect(msg.destinationId, 'receiver-0');
      expect(msg.namespace, CastProtocol.receiverNamespace);
      expect(msg.json['type'], 'GET_STATUS');
    });

    test('survives unicode titles and binary payloads', () {
      final msg = CastProtocol.decode(CastProtocol.encode(
        sourceId: 's',
        destinationId: 'd',
        namespace: 'n',
        payloadUtf8: jsonEncode({'title': 'Bésame nella notte 🎵'}),
        payloadBinary: const [1, 2, 3],
      ));
      expect(msg.json['title'], 'Bésame nella notte 🎵');
      expect(msg.payloadBinary, [1, 2, 3]);
    });

    test('LOAD carries the LAN relay URL and Cast session', () {
      final body = CastProtocol.load(
        requestId: 9,
        sessionId: 'session-1',
        contentId: 'http://192.168.1.10:52975/audio?id=abc&quality=high',
        contentType: 'audio/mpeg',
        title: 'Song',
        artist: 'Artist',
        imageUrl: 'https://img/1.jpg',
        durationMs: 210000,
      );
      expect(body['type'], 'LOAD');
      expect(body['sessionId'], 'session-1');
      expect(body['autoplay'], isTrue);
      final media = body['media'] as Map<String, dynamic>;
      expect(media['contentId'], contains('192.168.1.10'));
      expect(media['streamType'], 'BUFFERED');
      expect((media['metadata'] as Map)['duration'], 210.0);
    });

    test('commands use the media namespace session id', () {
      final seek = CastProtocol.playbackCommand('SEEK',
          requestId: 1, mediaSessionId: 7, positionMs: 30000);
      expect(seek['mediaSessionId'], 7);
      expect((seek['seekOptions'] as Map)['position'], 30.0);
    });
  });

  group('Cast discovery parsing (mDNS TXT)', () {
    test('parses friendly name, model and id', () {
      final txt = CastDevice.parseTxt(
        'id=641bf190#cd=8AF35E#fn=BRAVIA-VH1#md=BRAVIA#ic=0x0014',
      );
      expect(txt['fn'], 'BRAVIA-VH1');
      expect(txt['md'], 'BRAVIA');
      expect(txt['id'], '641bf190');

      final device = CastDevice.fromMdns(
        instanceName: 'BRAVIA-641b',
        host: '192.168.1.18',
        port: 8009,
        txt: 'id=641bf190#fn=BRAVIA-VH1#md=BRAVIA',
      );
      expect(device.name, 'BRAVIA-VH1');
      expect(device.kind, CastDeviceKind.tv);
      expect(device.host, '192.168.1.18');
    });

    test('classifies speakers and chromecasts like Android', () {
      expect(CastDeviceKindX.fromName('Nest Hub', 'Google Home'),
          CastDeviceKind.speaker);
      expect(CastDeviceKindX.fromName('Chromecast', 'Chromecast Ultra'),
          CastDeviceKind.chromecast);
    });
  });

  test('raw mDNS parses a Cast reply with compressed names', () {
    // Header (0 questions, 4 answers), then PTR + SRV + TXT + A records.
    List<int> name(String s) => s.split('.').map((l) {
          final b = utf8.encode(l);
          return [b.length, ...b];
        }).expand((x) => x).cast<int>().toList()..add(0);

    final instance = 'BRAVIA-VH1._googlecast._tcp.local';
    final target = 'bravia.local';
    List<int> rr(String n, int type, List<int> rdata) => [
          ...name(n),
          (type >> 8) & 0xff, type & 0xff,
          0, 1, // IN
          0, 0, 0, 120, // TTL
          (rdata.length >> 8) & 0xff, rdata.length & 0xff,
          ...rdata,
        ];
    final bytes = Uint8List.fromList([
      0, 0, // id
      0x84, 0, // response flags
      0, 0, // questions
      0, 4, // answers
      0, 0, 0, 0,
      ...rr('_googlecast._tcp.local', 12, name(instance)),
      ...rr(instance, 33, [
        0, 0, 0, 0, // priority/weight
        0x1f, 0x49, // port 8009
        ...name(target),
      ]),
      ...rr(instance, 16, [
        4, 0x69, 0x64, 0x3d, 0x31, // id=1
        5, 0x66, 0x6e, 0x3d, 0x54, 0x56, // fn=TV
      ]),
      ...rr(target, 1, [192, 168, 1, 18]),
    ]);
    final records = RawMdns.parse(bytes);
    expect(records.ptr['_googlecast._tcp.local'], instance);
    expect(records.srv[instance]!.port, 8009);
    expect(records.a[target], '192.168.1.18');
    final devices = CastDiscovery.devicesFrom(records);
    expect(devices, hasLength(1));
    expect(devices.first.name, 'TV');
    expect(devices.first.host, '192.168.1.18');

    // Unrelated services (AirPlay, Android TV remote) must be ignored.
    final mixed = MdnsRecords()
      ..merge(records)
      ..ptr['_androidtvremote2._tcp.local'] = 'Other._androidtvremote2._tcp.local'
      ..srv['Other._androidtvremote2._tcp.local'] =
          const SrvRecord('other.local', 6466);
    expect(CastDiscovery.devicesFrom(mixed), hasLength(1));
  });

  test('Cast receiver gets a LAN URL, local player keeps loopback', () {
    final local = 'http://127.0.0.1:51000/audio';
    final url = audioUrlForHost(local, '192.168.1.18', 'dQw4w9WgXcQ');
    expect(url, contains('192.168.1.18:51000'));
    expect(url, isNot(contains('127.0.0.1')));
    expect(Uri.parse(url).queryParameters['id'], 'dQw4w9WgXcQ');
    expect(Uri.parse(local).host, '127.0.0.1');
  });

  test('relay host prefers the Cast receiver subnet over WSL adapters', () {
    final addresses = ['172.21.208.1', '192.168.1.10', '169.254.83.107'];
    expect(pickLanAddress(addresses, '192.168.1.18'), '192.168.1.10');
    expect(pickLanAddress(addresses, null), '192.168.1.10');
    expect(pickLanAddress(['172.21.208.1'], '192.168.1.18'), '172.21.208.1');
  });
}
