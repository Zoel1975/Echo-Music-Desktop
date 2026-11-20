import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/cookie_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}\\echo_hive_cookie_account_test');
    await Hive.openBox('COOKIES');
    await Hive.openBox('ACCOUNT');
  });

  test('saveAccount round-trips: account[name] is readable after login', () async {
    await CookieStore.instance.clearAccount();
    await CookieStore.instance.saveAccount({
      'name': 'Mario Rossi',
      'email': 'mario@gmail.com',
      'channelHandle': '@mario',
      'signedIn': true,
    });

    final account = CookieStore.instance.account;
    expect(account['name'], 'Mario Rossi',
        reason: 'AccountPage reads account[name] to decide if signed in');
    expect(account['email'], 'mario@gmail.com');
    expect(account['signedIn'], isTrue);
  });

  test('cookieHeader is non-null after importing auth cookies', () async {
    await CookieStore.instance.clear();
    expect(CookieStore.instance.cookieHeader, isNull);
    await CookieStore.instance.importCookieHeader('SAPISID=abc; SID=xyz');
    expect(CookieStore.instance.cookieHeader, contains('SAPISID=abc'));
    expect(CookieStore.instance.cookieHeader, contains('SID=xyz'));
  });
}
