import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:Echo/services/google_login_service.dart';

/// End-to-end login read-path verification: launches Chrome through the app's
/// GoogleLoginService, then checks diagnostics()/readCookies()/collect().
void main() {
  const port = 9443;

  Future<void> waitCdpUp() async {
    for (var i = 0; i < 40; i++) {
      if (await GoogleLoginService.isCdpUp(port)) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  test('login plumbing: Chrome launches + CDP up + readCookies non-null',
      () async {
    final svc = GoogleLoginService(port: port);
    final profile = Directory('${Directory.systemTemp.path}\\echo-login-e2e-$port');
    try {
      final opened = await svc.openBrowser(profileDir: profile.path);
      expect(opened, isTrue, reason: 'chrome should launch via openBrowser');
      await waitCdpUp();
      expect(await GoogleLoginService.isCdpUp(port), isTrue,
          reason: 'CDP should be up after launch');
      final cookies = await svc.readCookies();
      expect(cookies, isNotNull, reason: 'readCookies should return a list');
      final d = await svc.diagnostics();
      expect(d.cookieCount, isA<int>());
      print('DIAG: cookieCount=${d.cookieCount} hasAuth=${d.hasAuth}');
    } finally {
      svc.closeBrowser();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  }, timeout: Timeout(Duration(minutes: 3)));
}
