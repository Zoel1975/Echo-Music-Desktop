import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Desktop port of `ui/screens/LoginScreen.kt`: a real WebView2 login page.
///
/// The user signs in with Google inside the app; the cookies written by the
/// WebView are copied into the `CookieStore` Hive box and merged into every
/// `YTClient` request. This widget embeds the native `Webview` view — without
/// it the controller would load the page off-screen and the user would see
/// nothing.
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
  String? _error;
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
      setState(() => _error = 'Google sign-in is only available on Windows.');
      return;
    }
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        setState(() => _error =
            'WebView2 Runtime is not installed. Install Microsoft Edge WebView2 Runtime and restart the app.');
        return;
      }
      await controller.initialize();
      await controller.setUserAgent(_userAgent);
      _urlSub = controller.url.listen((url) {
        if (_loggingIn) return;
        final host = Uri.tryParse(url)?.host ?? '';
        final isYtHost =
            host == 'music.youtube.com' || host.endsWith('.music.youtube.com');
        final isGoogle = host == 'youtube.com' ||
            host.endsWith('.youtube.com') ||
            host == 'g.co' ||
            host == 'accounts.google.com';
        if (isYtHost || isGoogle) _onAuthenticated();
      });
      await controller.loadUrl('https://music.youtube.com/login');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the login page: $e');
    }
  }

  Future<void> _onAuthenticated() async {
    if (_loggingIn || !mounted) return;
    _loggingIn = true;
    await CookieStore.instance.captureFromWebView(controller);
    if (CookieStore.instance.cookieHeader == null) {
      _loggingIn = false;
      return;
    }
    final info = await GetIt.I<YTMusic>().getAccountInfo();
    await CookieStore.instance.saveAccount(info ?? {'name': 'YouTube Music'});
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to YouTube Music'),
        actions: [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Done'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sign in with Google, then press Done.'),
                ),
                Expanded(child: Webview(controller)),
              ],
            ),
    );
  }
}
