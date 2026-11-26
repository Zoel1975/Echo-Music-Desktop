import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level evidence for the full login chain. Widget-level E2E is covered
/// by login_e2e_cdp_test.dart (real Chrome + CDP); this asserts the app-side
/// steps that make a detected session actually visible and usable.
void main() {
  test('login chain imports cookies, refreshes session, saves account, refetches', () {
    final page = File('lib/screens/login/login_page.dart').readAsStringSync();
    for (final step in [
      'importCookieHeader',
      'resetVisitorId()',
      'refreshHeaders()',
      'saveAccount(',
      'notifyAccountChanged()',
      "context.go('/')",
      'verifySession: _verifySession',
    ]) {
      expect(page, contains(step), reason: 'login chain missing: $step');
    }
  });

  test('auth detection has API-based fallback for renamed cookies', () {
    final svc = File('lib/services/google_login_service.dart').readAsStringSync();
    expect(svc, contains('verifySession'));
    expect(svc, contains('await verifySession(collected.pairs)'));
    final page = File('lib/screens/login/login_page.dart').readAsStringSync();
    expect(page, contains('getAccountInfo()'));
  });

  test('account getter unwraps saved info (fixes "returns home but not signed in")', () {
    final store = File('lib/services/cookie_store.dart').readAsStringSync();
    expect(store, contains("_accountBox.get('info')"));
  });
}
