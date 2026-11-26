import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/device_link_announcement.dart';

void main() {
  group('accountFingerprint (YouTube Music account link)', () {
    test('same account → same fingerprint; empty when logged out', () {
      final a = accountFingerprint({'SAPISID': 'x', 'SID': 'y'});
      final b = accountFingerprint({'SID': 'y', 'SAPISID': 'x'});
      expect(a, isNotEmpty);
      expect(b, a);
      expect(accountFingerprint({}), '');
    });

    test('different accounts → different fingerprints', () {
      expect(accountFingerprint({'SAPISID': 'a'}),
          isNot(accountFingerprint({'SAPISID': 'b'})));
    });
  });

  group('DeviceLinkAnnounce (link via playback state)', () {
    test('round-trips through bytes with proto filtering', () {
      final a = DeviceLinkAnnounce(
        id: 'desktop-123',
        name: 'Laptop',
        account: 'fp',
        playing: true,
        songId: 'videoId',
        title: 'Song',
        updatedAt: 99,
      );
      final parsed = DeviceLinkAnnounce.fromBytes(a.toBytes());
      expect(parsed, isNotNull);
      expect(parsed!.id, 'desktop-123');
      expect(parsed.name, 'Laptop');
      expect(parsed.account, 'fp');
      expect(parsed.playing, isTrue);
      expect(parsed.songId, 'videoId');
      expect(parsed.title, 'Song');
      expect(parsed.updatedAt, 99);
    });

    test('null when bytes are not an announce or proto differs', () {
      expect(DeviceLinkAnnounce.fromBytes(utf8.encode('{"hello":1}')), isNull);
      expect(
        DeviceLinkAnnounce.fromBytes(utf8.encode('{"proto":"other"}')),
        isNull,
      );
    });

    test('empty id defaults to "desktop"', () {
      final a = DeviceLinkAnnounce(id: '', name: 'N', account: '', updatedAt: 0);
      expect(DeviceLinkAnnounce.fromBytes(a.toBytes())?.id, 'desktop');
    });
  });

  test('playingStateJson carries the current track state', () {
    final j = playingStateJson(true, songId: 's1', title: 'T');
    expect(j['proto'], announceProto);
    expect(j['playing'], isTrue);
    expect(j['songId'], 's1');
    expect(j['title'], 'T');
  });
}
