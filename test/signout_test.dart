import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/account_refresh.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/session_service.dart';

/// Behavioral proof that "Sign out" really removes the session: after
/// `SessionService.signOut()` there is no cookie, no account, no dataSyncId,
/// no visitor id, the login browser profile is cleared and every data screen
/// is told to refetch.
void main() {
  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_signout_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('COOKIES')) await Hive.openBox('COOKIES');
    if (!Hive.isBoxOpen('ACCOUNT')) await Hive.openBox('ACCOUNT');
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
  });

  test('signOut clears every stored session value', () async {
    await Hive.box('COOKIES').put('SAPISID', 'auth');
    await Hive.box('COOKIES').put('SID', 'auth2');
    await Hive.box('ACCOUNT').put('info', {'name': 'Test User', 'signedIn': true});
    await Hive.box('SETTINGS').put('VISITOR_ID', 'visitor');
    await Hive.box('SETTINGS').put('DATASYNC_ID', 'datasync');

    // Sanity: the session is visible before signing out.
    expect(CookieStore.instance.cookieHeader, isNotNull);
    expect(CookieStore.instance.account['name'], 'Test User');
    expect(CookieStore.instance.dataSyncId, 'datasync');

    var profileCleared = false;
    var refreshed = false;
    final epochBefore = accountEpoch.value;

    final service = SessionService(
      clearBrowserProfile: () async => profileCleared = true,
      refreshClient: () async => refreshed = true,
    );
    await service.signOut();

    expect(CookieStore.instance.cookieHeader, isNull,
        reason: 'no Cookie header must be sent after sign out');
    expect(CookieStore.instance.account, isEmpty,
        reason: 'account page must show "Not signed in"');
    expect(CookieStore.instance.dataSyncId, isNull,
        reason: 'user.onBehalfOfUser must be gone');
    expect(Hive.box('SETTINGS').get('VISITOR_ID'), isNull);
    expect(profileCleared, isTrue,
        reason: 'the login browser must be signed out too');
    expect(refreshed, isTrue, reason: 'client headers must be rebuilt');
    expect(accountEpoch.value, epochBefore + 1,
        reason: 'data screens must refetch anonymously');
  });
}
