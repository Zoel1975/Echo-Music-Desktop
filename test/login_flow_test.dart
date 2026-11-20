import 'package:Echo/screens/login/login_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CDP cookie filtering', () {
    test('recognises YouTube auth cookies', () {
      expect(isAuthCookie('SAPISID'), isTrue);
      expect(isAuthCookie('__Secure-3PAPISID'), isTrue);
      expect(isAuthCookie('VISITOR_INFO1_LIVE'), isFalse);
    });

    test('accepts only Google/YouTube domains and subdomains', () {
      expect(isAllowedCookieDomain('.youtube.com'), isTrue);
      expect(isAllowedCookieDomain('accounts.google.com'), isTrue);
      expect(isAllowedCookieDomain('.github.com'), isFalse);
    });
  });
}
