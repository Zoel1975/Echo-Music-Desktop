import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/google_login_service.dart';
import 'package:Echo/services/stream_resolver.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Google sign-in for YouTube Music on desktop. Opens the system browser with
/// remote debugging, waits for a real Google auth cookie, imports it into the
/// app and returns home — no manual cookie copying.
///
/// Pure login logic lives in [GoogleLoginService]; this widget only drives
/// UI state. A manual cookie-paste fallback is kept for locked-down browsers.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _service = GoogleLoginService();
  final _cookieController = TextEditingController();
  Timer? _timeout;
  bool _opening = false;
  bool _checking = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _timeout?.cancel();
    _service.closeBrowser();
    _cookieController.dispose();
    super.dispose();
  }

  Future<String> _profileDir() async {
    final support = await getSupportDir();
    final dir = Directory('${support.path}/login-browser');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _finishLogin(Map<String, String> pairs) async {
    await CookieStore.instance.importCookieHeader(
        pairs.entries.map((e) => '${e.key}=${e.value}').join('; '));
    Map<String, dynamic>? info;
    try {
      info = await GetIt.I<YTMusic>().getAccountInfo();
    } catch (_) {}
    await CookieStore.instance.saveAccount({
      'name': info?['name'] ?? 'YouTube Music',
      if (info != null) ...info,
      'signedIn': true,
    });
    StreamResolver.instance.clearCache();
    _service.closeBrowser();
    if (mounted) {
      setState(() => _status = 'Accesso effettuato.');
      context.go('/');
    }
  }

  Future<void> _openBrowser() async {
    setState(() {
      _opening = true;
      _error = null;
      _status = 'Apertura del browser per il login…';
    });
    final profile = await _profileDir();
    final opened = await _service.openBrowser(profileDir: profile);
    if (!opened) {
      setState(() {
        _opening = false;
        _error = 'Nessun browser (Chrome/Edge) trovato.';
      });
      return;
    }
    setState(() {
      _opening = false;
      _status = 'Accedi nel browser. Il rilevamento è automatico…';
    });

    _timeout?.cancel();
    _timeout = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      _service.closeBrowser();
      setState(() {
        _checking = false;
        _error = 'Timeout: accedi entro 5 minuti.';
        _status = null;
      });
    });

    final pairs = await _service.waitForSignIn(
      timeout: const Duration(minutes: 5),
      cancelled: () async => !mounted,
    );
    _timeout?.cancel();
    if (pairs != null && mounted) {
      await _finishLogin(pairs);
    } else if (mounted) {
      setState(() {
        _error = 'Cookie di accesso non rilevati. Riprova o incolla il cookie.';
        _status = null;
      });
    }
  }

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _error = null;
      _status = 'Lettura dei cookie dal browser…';
    });
    final cookies = await _service.readCookies();
    final collected = cookies == null
        ? null
        : GoogleLoginService.collect(cookies);
    if (collected != null &&
        collected.hasAuth &&
        collected.pairs.isNotEmpty) {
      await _finishLogin(collected.pairs);
    } else {
      setState(() {
        _checking = false;
        _error = 'Nessun cookie di accesso trovato. Fai il login nel browser.';
        _status = null;
      });
    }
  }

  Future<void> _pasteCookies() async {
    final raw = _cookieController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Incolla prima il cookie dal browser.');
      return;
    }
    await _finishLogin(CookieStore.parseCookieHeader(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accedi con Google'),
        actions: [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Accedi a YouTube Music',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Si aprirà il browser. Dopo il login Google l\'app rileverà '
                'automaticamente la sessione e tornerà alla home.',
              ),
              const SizedBox(height: 24),
              if (_opening || _checking)
                const LinearProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _openBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri il browser e accedi'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _checking ? null : _checkNow,
                icon: const Icon(Icons.verified_user),
                label: const Text('Ho già effettuato il login — verifica'),
              ),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(_status!, style: const TextStyle(color: Colors.green)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Fallback — incolla l\'header Cookie da DevTools',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _cookieController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Cookie incollato dal browser',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _pasteCookies,
                child: const Text('Importa cookie del browser'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Directory> getSupportDir() async {
  final dir =
      Directory('${Platform.environment['LOCALAPPDATA']}\\com.echo\\Echo Music');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}
