import 'package:Echo/services/cookie_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CookieStore.buildCookieHeader', () {
    test('builds a "name=value; name2=value2" header string', () {
      expect(
        CookieStore.buildCookieHeader({
          'SAPISID': 'abc',
          '__Secure-YT-Logged-In': 'xyz',
        }),
        'SAPISID=abc; __Secure-YT-Logged-In=xyz',
      );
    });

    test('returns empty string for no cookies', () {
      expect(CookieStore.buildCookieHeader({}), isEmpty);
    });
  });
}
