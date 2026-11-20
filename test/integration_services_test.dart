import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/scrobble_service.dart';
import 'package:Echo/services/song_dna_service.dart';
import 'package:Echo/services/cloud_service.dart';
import 'package:Echo/services/discord_rpc_service.dart';
import 'package:Echo/services/listen_together_service.dart';

void main() {
  group('ScrobbleService (Last.fm / ListenBrainz)', () {
    test('Last.fm signature is a 32-char MD5 and deterministic', () {
      final p = {'artist': 'A', 'track': 'T', 'method': 'track.scrobble'};
      final a = ScrobbleService.lastfmSignature(p, 'secret');
      final b = ScrobbleService.lastfmSignature(p, 'secret');
      expect(a, b);
      expect(a.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue);
    });

    test('Last.fm params include method, api_sig and timestamp', () {
      final p = ScrobbleService.lastfmParams(
        method: 'track.scrobble',
        apiKey: 'key',
        sessionKey: 'sk',
        secret: 'sec',
        artist: 'Artist',
        track: 'Track',
        timestamp: 12345,
        album: 'Album',
      );
      expect(p['method'], 'track.scrobble');
      expect(p['api_key'], 'key');
      expect(p['timestamp'], '12345');
      expect(p['album'], 'Album');
      expect(p['api_sig'], isNotEmpty);
    });

    test('ListenBrainz payload plays single vs playing-now', () {
      final single = ScrobbleService.listenBrainzPayload(
        artist: 'A', track: 'T', album: 'Al', timestamp: 99, singleRelease: true);
      expect(single['listen_type'], 'single');
      expect((single['payload'] as List).first['listened_at'], 99);
      final now = ScrobbleService.listenBrainzPayload(
        artist: 'A', track: 'T', album: '', timestamp: 99, singleRelease: false);
      expect(now['listen_type'], 'playing_now');
      expect((now['payload'] as List).first.containsKey('listened_at'), isFalse);
      final meta = (now['payload'] as List).first['track_metadata'];
      expect(meta['artist_name'], 'A');
      expect((meta as Map).containsKey('release_name'), isFalse);
    });
  });

  group('SongDnaService', () {
    test('extracts first Genius hit full_title', () {
      final json = jsonDecode('{"response":{"hits":[{"result":{"full_title":"Song by Artist"}}]}}');
      expect(SongDnaService.geniusFirstHit(json), 'Song by Artist');
      expect(SongDnaService.geniusFirstHit({'response': {'hits': []}}), isNull);
    });

    test('extracts Wikipedia extract', () {
      expect(SongDnaService.wikipediaExtract({'extract': 'A song.'}), 'A song.');
      expect(SongDnaService.wikipediaExtract({}), isNull);
    });

    test('wikipedia URL encodes title and language', () {
      final url = SongDnaService.wikipediaSummary('it', 'A Song');
      expect(url, contains('it.wikipedia.org'));
      expect(url, contains('A%20Song'));
    });
  });

  group('CloudService', () {
    test('normalizes trailing slashes', () {
      expect(CloudService.normalizeUrl('http://x/'), 'http://x');
      expect(CloudService.normalizeUrl('http://x///'), 'http://x');
    });

    test('jellyfin auth header contains user and token', () {
      final h = CloudService.jellyfinAuth(user: 'u', password: 'p');
      expect(h, contains('UserId="u"'));
      expect(h, contains('Token="p"'));
    });

    test('navidrome ping parse', () {
      expect(CloudService.parseNavidromePing({'status': 'OK'}), isTrue);
      expect(CloudService.parseNavidromePing({'status': 'fail'}), isFalse);
    });
  });

  group('DiscordRpcService', () {
    test('activity payload type mapping', () {
      final p = DiscordRpcService.activityPayload(
        name: 'Echo Music', details: 'Track', state: 'Artist',
        activityType: 'Listening', showWhenPaused: true, nonce: 1);
      expect(p['cmd'], 'SET_ACTIVITY');
      expect((p['args'] as Map)['activity']['type'], 2);
      expect((p['args'] as Map)['activity']['details'], 'Track');
      expect(DiscordRpcService.activityPayload(
        name: 'n', details: 'd', state: 's', activityType: 'Playing',
        showWhenPaused: false, nonce: 2)['args']['activity']['type'], 0);
    });

    test('handshake URL uses the in-app client id', () {
      final url = DiscordRpcService.authorizeUrl('my-app-id');
      expect(url, startsWith('ws://127.0.0.1:6463/'));
      expect(url, contains('client_id=my-app-id'));
      expect(url, contains('v=1'));
      expect(url, contains('encoding=json'));
      // No hardcoded id leaked.
      expect(url, isNot(contains('112233445566778899')));
    });

    test('AUTHENTICATE command carries the in-app access token', () {
      final p = DiscordRpcService.authenticatePayload(
        accessToken: 'entered-token', nonce: 7);
      expect(p['cmd'], 'AUTHENTICATE');
      expect(p['args']['access_token'], 'entered-token');
      expect(p['nonce'], '7');
    });
  });

  group('ListenTogetherService (real LAN protocol)', () {
    test('state round-trips through JSON', () {
      final s = ListenState(
        username: 'alice', songId: 'abc', title: 'Song',
        positionMs: 12000, playing: true, updatedAt: 99);
      final decoded = ListenState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(decoded.username, 'alice');
      expect(decoded.songId, 'abc');
      expect(decoded.positionMs, 12000);
      expect(decoded.playing, isTrue);
    });
  });
}
