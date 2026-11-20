import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/google_login_service.dart';
import 'package:Echo/services/device_link_service.dart';

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
      expect(result.pairs.containsKey('SAPISID'), isTrue);
      expect(result.pairs.containsKey('SID'), isTrue);
      expect(result.pairs.containsKey('tracker'), isFalse);
    });

    test('no auth cookie means not signed in', () {
      final result = GoogleLoginService.collect([
        {'name': 'VISITOR_INFO1_LIVE', 'value': '1', 'domain': '.youtube.com'},
      ]);
      expect(result.hasAuth, isFalse);
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

  group('DeviceLinkService (mobile <-> desktop pairing)', () {
    test('generates a 6-digit code', () {
      final code = DeviceLinkService.generateCode(Random(1));
      expect(code.length, 6);
      expect(code, matches(RegExp(r'^\d{6}$')));
    });

    test('pair request validates the code and required fields', () {
      final ok = DeviceLinkService.parsePairRequest(
        {
          'code': '123456',
          'deviceName': 'Pixel',
          'cookieHeader': 'SAPISID=abc;',
        },
        '123456',
      );
      expect(ok.ok, isTrue);
      expect(ok.deviceName, 'Pixel');
      expect(ok.cookieHeader, 'SAPISID=abc;');

      final wrong = DeviceLinkService.parsePairRequest(
        {'code': '000000', 'deviceName': 'Pixel', 'cookieHeader': 'x=y'},
        '123456',
      );
      expect(wrong.ok, isFalse);

      final missing = DeviceLinkService.parsePairRequest(
        {'code': '123456', 'deviceName': 'Pixel'},
        '123456',
      );
      expect(missing.ok, isFalse);
    });
  });
}
