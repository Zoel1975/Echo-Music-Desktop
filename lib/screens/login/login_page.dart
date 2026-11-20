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
/// Whether a WebView navigation means the user is done signing in.
/// Login/consent/sign-in pages never count, even on youtube.com hosts.
bool shouldAutoCompleteLogin(Uri uri) {
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (host.contains('google.com') ||
      path.contains('/login') ||
      path.contains('signin') ||
      path.contains('consent')) {
    return false;
  }
  return host == 'music.youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'youtube.com';
}

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
  final _cookieController = TextEditingController();
  bool _loggingIn = false;
  bool _importing = false;
  String? _error;
  String? _info;
  StreamSubscription<String>? _urlSub;

  @override
  void initState() {
    super.initState();
    _login();
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    _cookieController.dispose();
    controller.dispose();
    super.dispose();
  }

  /// Imports the `Cookie:` header copied from a signed-in browser (DevTools →
  /// Network → music.youtube.com → Headers → Cookie).
  Future<void> _importCookies() async {
    final raw = _cookieController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Incolla prima il cookie dal browser.');
      return;
    }
    setState(() {
      _importing = true;
      _error = null;
      _info = null;
    });
    try {
      final count = await CookieStore.instance.importCookieHeader(raw);
      if (count == 0) {
        setState(() => _error = 'Nessun cookie valido trovato nel testo.');
        return;
      }
      final info = await GetIt.I<YTMusic>().getAccountInfo();
      await CookieStore.instance.saveAccount(info ?? {'name': 'YouTube Music'});
      if (!mounted) return;
      setState(() => _info = 'Importati $count cookie. Accesso verificato.');
      context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = 'Import cookie fallito: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
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
        unawaited(_onUrlChanged(url));
      });
      await controller.loadUrl('https://music.youtube.com/login');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the login page: $e');
    }
  }

  static const _authCookies = {
    'SID',
    'HSID',
    'SSID',
    'APISID',
    'SAPISID',
    '__Secure-3PAPISID',
    '__Secure-1PAPISID',
    '__Secure-3PSID',
    'LOGIN_INFO',
  };

  Future<void> _onUrlChanged(String url) async {
    if (_loggingIn) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !shouldAutoCompleteLogin(uri)) return;
    final cookies = await controller.getCookies('https://music.youtube.com/');
    if (!cookies.any((c) => _authCookies.contains(c.name))) return;
    await _completeLogin();
  }

  Future<void> _completeLogin() async {
    if (_loggingIn || !mounted) return;
    setState(() => _loggingIn = true);
    await CookieStore.instance.captureFromWebView(controller);
    final info = await GetIt.I<YTMusic>().getAccountInfo();
    await CookieStore.instance.saveAccount(info ?? {'name': 'YouTube Music'});
    if (!mounted) return;
    setState(() => _info = 'Accesso effettuato');
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to YouTube Music'),
        actions: [
          TextButton(
            onPressed: _completeLogin,
            child: const Text('Verifica login'),
          ),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Oppure: accedi a music.youtube.com nel browser, poi copia '
                    'l\'header Cookie da DevTools → Network → richiesta a '
                    'music.youtube.com → Headers e incollalo qui.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _cookieController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cookie incollato dal browser',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _importing
                      ? const LinearProgressIndicator()
                      : FilledButton.icon(
                          onPressed: _importCookies,
                          icon: const Icon(Icons.login),
                          label: const Text('Importa cookie del browser'),
                        ),
                ),
                if (_info != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_info!, style: const TextStyle(color: Colors.green)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
