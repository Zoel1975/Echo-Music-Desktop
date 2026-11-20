import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/google_login_service.dart';

void main() {
  group('Google login cookie filtering', () {
    test('recognises YouTube auth cookies', () {
      expect(GoogleLoginService.authCookies.contains('SAPISID'), isTrue);
      expect(
          GoogleLoginService.authCookies.contains('__Secure-3PAPISID'), isTrue);
      expect(
          GoogleLoginService.authCookies.contains('VISITOR_INFO1_LIVE'), isFalse);
    });

    test('accepts only Google/YouTube domains and subdomains', () {
      expect(GoogleLoginService.isAllowedDomain('.youtube.com'), isTrue);
      expect(GoogleLoginService.isAllowedDomain('accounts.google.com'), isTrue);
      expect(GoogleLoginService.isAllowedDomain('.github.com'), isFalse);
    });

    test('collect filters cookies and detects real sign-in', () {
      final result = GoogleLoginService.collect([
        {
          'name': 'SAPISID',
          'value': 'abc',
          'domain': '.youtube.com',
        },
        {
          'name': 'SID',
          'value': 'xyz',
          'domain': '.google.com',
        },
        {
          'name': 'tracker',
          'value': 'no',
          'domain': '.evil.com',
        },
      ]);
      expect(result.hasAuth, isTrue);
      expect(result.youtubeAuth, isTrue);
      expect(result.pairs.containsKey('SAPISID'), isTrue);
      // Android reads only the music.youtube.com cookie jar: a google.com-only
      // cookie is not sent when YouTube already carries the session.
      expect(result.pairs.containsKey('SID'), isFalse);
      expect(result.pairs.containsKey('tracker'), isFalse);
    });

    test('no auth cookie means not signed in', () {
      final result = GoogleLoginService.collect([
        {'name': 'VISITOR_INFO1_LIVE', 'value': '1', 'domain': '.youtube.com'},
      ]);
      expect(result.hasAuth, isFalse);
      expect(result.youtubeAuth, isFalse);
    });
  });

  group('GoogleLoginService diagnostics (login verification)', () {
    test('diagnostics with no browser/cookies reports empty state', () async {
      // Point the service at a closed port: no browser, no CDP.
      final svc = GoogleLoginService(port: 1);
      final d = await svc.diagnostics();
      expect(d.cookieCount, 0);
      expect(d.hasAuth, isFalse);
      expect(await GoogleLoginService.isCdpUp(1), isFalse);
    });
  });

  // Linking moved to the YouTube-Music playback-state mechanism (see
  // device_link_announcement_test.dart); the old 6-digit code flow is gone.
}
