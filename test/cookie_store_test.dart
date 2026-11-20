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

  group('CookieStore.parseCookieHeader', () {
    test('parses a browser Cookie header into name=value pairs', () {
      final parsed = CookieStore.parseCookieHeader(
        'SID=abc123; HSID=x; __Secure-3PAPISID=tok; CONSENT=YES+1',
      );
      expect(parsed['SID'], 'abc123');
      expect(parsed['HSID'], 'x');
      expect(parsed['__Secure-3PAPISID'], 'tok');
      expect(parsed['CONSENT'], 'YES+1');
    });

    test('ignores malformed entries', () {
      final parsed = CookieStore.parseCookieHeader('a=1; ; =x; b=2');
      expect(parsed, {'a': '1', 'b': '2'});
    });
  });
}
