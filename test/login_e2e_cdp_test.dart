import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/google_login_service.dart';

/// End-to-end login read-path verification: launches Chrome through the app's
/// GoogleLoginService, then checks diagnostics()/readCookies()/collect() and
/// the `window.yt.config_` extraction used by the real login flow.
///
/// Heavy (launches Chrome) so skipped by default:
///   flutter test test/login_e2e_cdp_test.dart --run-skipped
void main() {
  Future<void> waitCdpUp(int p) async {
    for (var i = 0; i < 40; i++) {
      if (await GoogleLoginService.isCdpUp(p)) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  test('login plumbing: Chrome launches + CDP up + readCookies non-null',
      () async {
    const port = 9443;
    final svc = GoogleLoginService(port: port);
    final profile =
        Directory('${Directory.systemTemp.path}\\echo-login-e2e-$port');
    try {
      final opened = await svc.openBrowser(profileDir: profile.path);
      expect(opened, isTrue, reason: 'chrome should launch via openBrowser');
      await waitCdpUp(port);
      expect(await GoogleLoginService.isCdpUp(port), isTrue,
          reason: 'CDP should be up after launch');
      final cookies = await svc.readCookies();
      expect(cookies, isNotNull, reason: 'readCookies should return a list');
      final d = await svc.diagnostics();
      expect(d.cookieCount, isA<int>());
      // ignore: avoid_print
      print('DIAG: cookieCount=${d.cookieCount} hasAuth=${d.hasAuth}');
    } finally {
      svc.closeBrowser();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }, skip: true, timeout: Timeout(Duration(minutes: 3)));

  test('reads VISITOR_DATA from a real music.youtube.com page (Android path)',
      () async {
    const ytPort = 9444;
    final svc = GoogleLoginService(port: ytPort);
    final profile =
        Directory('${Directory.systemTemp.path}\\echo-login-yt-$ytPort');
    try {
      final opened = await svc.openBrowser(
        profileDir: profile.path,
        url: 'https://music.youtube.com/',
      );
      expect(opened, isTrue);
      await waitCdpUp(ytPort);
      expect(await GoogleLoginService.isCdpUp(ytPort), isTrue,
          reason: 'CDP should be up for the YouTube Music page');
      // The page shell needs a moment to define window.yt.config_.
      var resolved = await svc.readSessionState();
      for (var i = 0; i < 20 && resolved?.visitorData == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        resolved = await svc.readSessionState();
      }
      // ignore: avoid_print
      print('SESSION: visitor=${resolved?.visitorData} '
          'dataSync=${resolved?.dataSyncId} signedIn=${resolved?.signedIn}');
      expect(resolved, isNotNull,
          reason: 'Runtime.evaluate must read window.yt.config_');
      expect(resolved!.visitorData, isNotNull,
          reason: 'VISITOR_DATA must be readable from the page');
    } finally {
      svc.closeBrowser();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }, skip: true, timeout: Timeout(Duration(minutes: 3)));

  test('reads session state from www.youtube.com too (Google redirect)', () async {
    const ytPort = 9447;
    final svc = GoogleLoginService(port: ytPort);
    final profile =
        Directory('${Directory.systemTemp.path}\\echo-login-www-$ytPort');
    try {
      final opened = await svc.openBrowser(
        profileDir: profile.path,
        url: 'https://www.youtube.com/',
      );
      expect(opened, isTrue);
      await waitCdpUp(ytPort);
      var resolved = await svc.readSessionState();
      for (var i = 0; i < 15 && resolved?.visitorData == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        resolved = await svc.readSessionState();
      }
      // ignore: avoid_print
      print('WWW SESSION: visitor=${resolved?.visitorData != null} '
          'signedIn=${resolved?.signedIn}');
      expect(resolved?.visitorData, isNotNull,
          reason: 'www.youtube.com must expose window.yt.config_ too');
    } finally {
      svc.closeBrowser();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }, skip: true, timeout: Timeout(Duration(minutes: 3)));
}
