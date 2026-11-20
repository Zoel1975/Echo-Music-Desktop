import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YT request headers do NOT claim gzip for plain JSON bodies', () {
    final src = File('lib/ytmusic/helpers.dart').readAsStringSync();
    expect(src, isNot(contains("'content-encoding': 'gzip'")),
        reason: 'content-encoding on requests makes YouTube reject browse/search');
  });

  test('request headers match Android InnerTube (client identity + origin)', () {
    final src = File('lib/ytmusic/helpers.dart').readAsStringSync();
    for (final header in [
      "'X-Origin'",
      "'Referer'",
      "'X-Goog-Api-Format-Version'",
      "'X-YouTube-Client-Name'",
      "'X-YouTube-Client-Version'",
      "ytmClientId = '67'",
      "ytmClientName = 'WEB_REMIX'",
    ]) {
      expect(src, contains(header), reason: 'missing Android header: $header');
    }
  });

  test('context carries visitorData and dataSyncId (onBehalfOfUser)', () {
    final src = File('lib/ytmusic/helpers.dart').readAsStringSync();
    expect(src, contains("'visitorData': visitorData"));
    expect(src, contains("'onBehalfOfUser': dataSyncId"));
    expect(src, contains("'DATASYNC_ID'"),
        reason: 'dataSyncId must be read from SETTINGS');
  });

  test('YT client drops stale Cookie + Authorization when signed out', () {
    final src = File('lib/ytmusic/client.dart').readAsStringSync();
    expect(src, contains('_applySessionHeaders'));
    expect(src, contains("target.remove('cookie')"));
    expect(src, contains("target.remove('Authorization')"));
    expect(src, contains("target['Authorization'] = auth"));
    expect(src, contains('CookieStore.instance.authorizationHeader'));
    // Both request paths must refresh auth (sendRequest + sendGetRequest).
    expect(RegExp(r'_applySessionHeaders\(').allMatches(src).length,
        greaterThanOrEqualTo(3));
  });

  test('SAPISIDHASH is built exactly like Android InnerTube.ytClient', () {
    final src = File('lib/services/cookie_store.dart').readAsStringSync();
    expect(src, contains('SAPISIDHASH'));
    expect(src, contains("sha1.convert(utf8.encode('\$ts \$sapisid \$origin'))"));
    expect(src, contains("origin = 'https://music.youtube.com'"));
  });

  test('login stores dataSyncId + visitorData before validating the account', () {
    final src = File('lib/screens/login/login_page.dart').readAsStringSync();
    final saveDataSync = src.indexOf('saveDataSyncId(session?.dataSyncId)');
    final getInfo = src.indexOf('getAccountInfo()');
    expect(saveDataSync, greaterThanOrEqualTo(0));
    expect(getInfo, greaterThan(0));
    expect(saveDataSync, lessThan(getInfo),
        reason: 'account/account_menu needs onBehalfOfUser');
    expect(src, contains("settings.put('VISITOR_ID', pageVisitor)"));
  });

  test('manual "check now" also requires a YouTube (not Google) session', () {
    final src = File('lib/screens/login/login_page.dart').readAsStringSync();
    expect(src, contains('collected.youtubeAuth ||'));
    expect(src, contains('Accesso Google presente, ma YouTube Music'));
    // The sign-in poll must never accept a google.com-only session.
    final svc = File('lib/services/google_login_service.dart').readAsStringSync();
    expect(svc, contains('if (collected.youtubeAuth) {'));
    expect(svc, contains('pending = capture;'));
  });

  test('logout follows Android forgetAccount: clear all + notify + home', () {
    final src = File('lib/services/session_service.dart').readAsStringSync();
    for (final step in [
      'CookieStore.instance.clear()',
      'CookieStore.instance.clearAccount()',
      "delete('VISITOR_ID')",
      'saveDataSyncId(null)',
      'resetVisitorId()',
      'refreshHeaders()',
      '_clearBrowserProfile()',
      'notifyAccountChanged()',
    ]) {
      expect(src, contains(step), reason: 'logout missing: $step');
    }
    final page = File('lib/screens/account/account_page.dart').readAsStringSync();
    expect(page, contains('SessionService().signOut()'));
    expect(page, contains("context.go('/')"));
    expect(page, contains("hasAccount = CookieStore.instance.cookieHeader != null ||"));
  });
}
