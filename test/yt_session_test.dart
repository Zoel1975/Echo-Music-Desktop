import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/google_login_service.dart';
import 'package:Echo/services/yt_session.dart';

void main() {
  group('GoogleLoginService.collect keeps YouTube cookies only', () {
    test('youtube.com SAPISID wins over google.com SAPISID', () {
      final result = GoogleLoginService.collect([
        {'name': 'SAPISID', 'value': 'GOOGLE-SAPISID', 'domain': '.google.com'},
        {'name': 'SAPISID', 'value': 'YOUTUBE-SAPISID', 'domain': '.youtube.com'},
        {'name': 'SID', 'value': 'GOOGLE-SID', 'domain': '.google.com'},
        {'name': 'SID', 'value': 'YOUTUBE-SID', 'domain': '.youtube.com'},
        {'name': 'LOGIN_INFO', 'value': 'li', 'domain': '.youtube.com'},
        {'name': 'NID', 'value': 'nid', 'domain': '.google.com'},
        {'name': 'evil', 'value': 'x', 'domain': '.evil.com'},
      ]);
      expect(result.hasAuth, isTrue);
      expect(result.youtubeAuth, isTrue);
      expect(result.pairs['SAPISID'], 'YOUTUBE-SAPISID');
      expect(result.pairs['SID'], 'YOUTUBE-SID');
      // Google-only cookies must NOT be sent to music.youtube.com when the
      // YouTube jar already carries the session (Android reads only that jar).
      expect(result.pairs.containsKey('NID'), isFalse);
      expect(result.pairs.containsKey('evil'), isFalse);
    });

    test('falls back to the merged jar when YouTube has no session yet', () {
      final result = GoogleLoginService.collect([
        {'name': 'SID', 'value': 'GOOGLE-SID', 'domain': '.google.com'},
        {'name': 'PREF', 'value': 'p', 'domain': '.youtube.com'},
      ]);
      expect(result.pairs.containsKey('PREF'), isTrue);
      expect(result.pairs.containsKey('SID'), isTrue);
      // A google.com-only session is NOT a YouTube login: the sign-in poll must
      // keep waiting for the redirect to music.youtube.com instead of saving a
      // session without DATASYNC_ID.
      expect(result.youtubeAuth, isFalse);
    });

    test('google.com auth alone is not a YouTube sign-in', () {
      final result = GoogleLoginService.collect([
        {'name': 'SAPISID', 'value': 'GOOGLE', 'domain': '.google.com'},
        {'name': 'SID', 'value': 'GOOGLE', 'domain': '.google.com'},
      ]);
      expect(result.hasAuth, isTrue);
      expect(result.youtubeAuth, isFalse);
    });

    test('domain helpers are exact', () {
      expect(GoogleLoginService.isYoutubeDomain('.youtube.com'), isTrue);
      expect(GoogleLoginService.isYoutubeDomain('music.youtube.com'), isTrue);
      expect(GoogleLoginService.isYoutubeDomain('.google.com'), isFalse);
    });
  });

  group('YtSession (window.yt.config_ payload)', () {
    test('parses VISITOR_DATA and DATASYNC_ID like Android', () {
      final s = YtSession.fromBrowserConfig({
        'VISITOR_DATA': 'Cgt2aXNpdG9y',
        'DATASYNC_ID': 'UCabc123||CHANNEL||',
        'LOGGED_IN': true,
      });
      expect(s.visitorData, 'Cgt2aXNpdG9y');
      expect(s.dataSyncId, 'UCabc123', reason: 'Android uses substringBefore("||")');
      expect(s.signedIn, isTrue);
    });

    test('short keys and empty values are handled', () {
      final s = YtSession.fromBrowserConfig({
        'visitorData': 'v',
        'dataSyncId': '',
        'LOGGED_IN': true,
      });
      expect(s.visitorData, 'v');
      expect(s.dataSyncId, isNull);
      expect(YtSession.fromBrowserConfig({}).isEmpty, isTrue);
    });
  });

  group('SAPISIDHASH authorization', () {
    test('matches the Android/Python algorithm', () {
      final value = CookieStore.buildSapisidHash(
        'sapisid',
        now: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(
        value,
        'SAPISIDHASH 1700000000_9a709cefbdc85cc64236c7b9098338ee28ca2e51',
      );
    });

    test('includes the timestamp prefix and underscore separator', () {
      final value = CookieStore.buildSapisidHash(
        'abc',
        now: DateTime.fromMillisecondsSinceEpoch(42 * 1000),
      );
      expect(value, startsWith('SAPISIDHASH 42_'));
      expect(value.split('_').first, 'SAPISIDHASH 42');
    });
  });
}
