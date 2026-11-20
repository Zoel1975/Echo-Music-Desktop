import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YT request headers do NOT claim gzip for plain JSON bodies', () {
    final src = File('lib/ytmusic/helpers.dart').readAsStringSync();
    expect(src, isNot(contains("'content-encoding': 'gzip'")),
        reason: 'content-encoding on requests makes YouTube reject browse/search');
  });

  test('YT client drops stale Cookie header when signed out', () {
    final src = File('lib/ytmusic/client.dart').readAsStringSync();
    // Both request paths must remove the header when cookieHeader == null.
    final removals = RegExp(r"effectiveHeaders\.remove\('cookie'\)|this\.headers\.remove\('cookie'\)")
        .allMatches(src)
        .length;
    expect(removals, greaterThanOrEqualTo(2),
        reason: 'sendGetRequest + sendRequest must mirror YouTube.cookie = null');
    expect(src, contains("headers['cookie'] = cookieHeader"));
  });

  test('logout follows Android forgetAccount: clear all + notify + home', () {
    final src = File('lib/screens/account/account_page.dart').readAsStringSync();
    for (final step in [
      'CookieStore.instance.clear()',
      'CookieStore.instance.clearAccount()',
      "delete('VISITOR_ID')",
      'resetVisitorId()',
      'notifyAccountChanged()',
      "context.go('/')",
      "hasAccount = CookieStore.instance.cookieHeader != null ||",
    ]) {
      expect(src, contains(step), reason: 'logout missing: $step');
    }
  });
}
