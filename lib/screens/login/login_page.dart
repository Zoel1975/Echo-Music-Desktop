import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Desktop port of `ui/screens/LoginScreen.kt`: the WebView2 login page.
///
/// The desktop needs no WebView in the Android sense; instead we drive the
/// shared WebView2 through `webview_flutter_windows`: cookies the user
/// enters on Google/YouTube sign-in are read from the WebView into the
/// `CookieStore` Hive box, then validated via
/// `YTClient.getAccountInfo()` (`account/account_menu`), then the user
/// returns to the app.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0';

  final controller = WebviewController();
  bool _loggingIn = false;
  StreamSubscription<String>? _urlSub;

  @override
  void initState() {
    super.initState();
    _login();
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!Platform.isWindows) {
      return;
    }
    await controller.initialize();
    await controller.setUserAgent(_userAgent);
    await controller.loadUrl('https://music.youtube.com/login');

    _urlSub = controller.url.listen((url) {
      if (_loggingIn) return;
      final host = Uri.tryParse(url)?.host ?? '';
      final isYtHost =
          host == 'music.youtube.com' || host.endsWith('.music.youtube.com');
      final isGoogle =
          host == 'youtube.com' || host.endsWith('.youtube.com') || host == 'g.co';
      if (!isYtHost && !isGoogle) return;
      _onAuthenticated();
    });
  }

  Future<void> _onAuthenticated() async {
    if (_loggingIn || !mounted) return;
    _loggingIn = true;
    await CookieStore.instance.captureFromWebView(controller);
    final info = await GetIt.I<YTMusic>().getAccountInfo();
    if (info == null) {
      _loggingIn = false;
      return;
    }
    await CookieStore.instance.saveAccount(info);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sign in with your Google or YouTube account',
              style: TextStyle(fontSize: 16),
            ),
          ),
          Text('Then you will be returned here automatically.'),
        ],
      ),
    );
  }
}
