import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/stream_resolver.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Login flow without the embedded WebView (which renders black on this
/// machine). We open Edge with a dedicated profile and a loopback CDP port;
/// after the user signs in, the cookies are read over the DevTools protocol
/// and imported into the app. No manual copy/paste is required.
bool isAuthCookie(String name) => _LoginPageState.authCookies.contains(name);

bool isAllowedCookieDomain(String domain) {
  final d = domain.toLowerCase();
  return _LoginPageState.allowedDomains
      .any((allowed) => d == allowed || d.endsWith('.$allowed'));
}

/// Pure helper: filters CDP cookies to Google/YouTube hosts and reports
/// whether a real sign-in cookie is present.
({Map<String, String> pairs, bool hasAuth}) collectAuthCookies(
  List<Map<String, dynamic>> cookies,
) {
  final pairs = <String, String>{};
  var hasAuth = false;
  for (final c in cookies) {
    final name = c['name'] as String? ?? '';
    final value = c['value'] as String? ?? '';
    final domain = (c['domain'] as String? ?? '').toLowerCase();
    if (!isAllowedCookieDomain(domain)) continue;
    if (isAuthCookie(name)) hasAuth = true;
    if (name.isNotEmpty && value.isNotEmpty) pairs[name] = value;
  }
  return (pairs: pairs, hasAuth: hasAuth);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _port = 9333;
  static const authCookies = {
    'SID', 'HSID', 'SSID', 'APISID', 'SAPISID',
    '__Secure-3PAPISID', '__Secure-1PAPISID', '__Secure-3PSID', 'LOGIN_INFO',
  };
  static const allowedDomains = [
    'youtube.com', 'google.com', 'gstatic.com', 'googleusercontent.com',
    'googleapis.com', 'g.co',
  ];

  final _cookieController = TextEditingController();
  Timer? _poll;
  bool _opening = false;
  bool _checking = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    _cookieController.dispose();
    super.dispose();
  }

  Future<String> _profileDir() async {
    final support = await getSupportDir();
    final dir = Directory('${support.path}/login-browser');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _openBrowser() async {
    setState(() {
      _opening = true;
      _error = null;
      _status = 'Apertura del browser per il login…';
    });
    try {
      final profile = await _profileDir();
      final candidates = [
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      ];
      final exe = candidates.firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => '',
      );
      if (exe.isEmpty) throw Exception('Né Edge né Chrome sono installati');
      await Process.start(exe, [
        '--remote-debugging-port=$_port',
        '--user-data-dir=$profile',
        '--no-first-run',
        '--no-default-browser-check',
        'https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F',
      ]);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _tryImport(fromPoll: true));
      setState(() => _status =
          'Accedi nel browser che si è aperto. Il rilevamento è automatico.');
    } catch (e) {
      setState(() {
        _error = 'Impossibile aprire il browser: $e';
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<List<Map<String, dynamic>>?> _cdpCookies() async {
    try {
      final tabs = await http
          .get(Uri.parse('http://127.0.0.1:$_port/json/list'))
          .timeout(const Duration(seconds: 3));
      final list = jsonDecode(tabs.body) as List<dynamic>;
      String? wsUrl;
      for (final target in list) {
        if (target is! Map) continue;
        if (target['type'] != 'page') continue;
        final url = (target['url'] as String? ?? '').toLowerCase();
        if (allowedDomains.any((d) => url.contains(d))) {
          wsUrl = target['webSocketDebuggerUrl'] as String?;
          if (wsUrl != null) break;
        }
      }
      if (wsUrl == null) return null;
      final ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      try {
        ws.add(jsonEncode({'id': 1, 'method': 'Network.getAllCookies'}));
        await for (final message in ws.timeout(const Duration(seconds: 5))) {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          if (decoded['id'] == 1) {
            final cookies = decoded['result']?['cookies'] as List<dynamic>? ?? [];
            return cookies
                .whereType<Map<String, dynamic>>()
                .map((c) => Map<String, dynamic>.from(c))
                .toList();
          }
        }
      } finally {
        await ws.close();
      }
    } catch (e) {
      debugPrint('[login] CDP read failed: $e');
    }
    return null;
  }

  Future<void> _tryImport({bool fromPoll = false}) async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final cookies = await _cdpCookies();
      if (cookies == null) {
        if (!fromPoll) {
          setState(() => _error =
              'Nessuna scheda di login trovata. Apri prima il browser.');
        }
        return;
      }
      final collected = collectAuthCookies(cookies);
      debugPrint(
        '[login] CDP cookies=${cookies.length} filtered=${collected.pairs.length} '
        'auth=${collected.hasAuth}',
      );
      if (!collected.hasAuth || collected.pairs.isEmpty) return;

      await CookieStore.instance.importCookieHeader(
        collected.pairs.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; '),
      );
      // account/account_menu may fail without a po-token: the auth cookies are
      // the source of truth for being signed in, so do not gate on this call.
      Map<String, dynamic>? info;
      try {
        info = await GetIt.I<YTMusic>().getAccountInfo();
      } catch (e) {
        debugPrint('[login] accountInfo failed (non-fatal): $e');
      }
      await CookieStore.instance.saveAccount({
        'name': info?['name'] ?? 'YouTube Music',
        if (info != null) ...info,
        'signedIn': true,
      });
      // Drop cached "bot check" failures so the next play uses the new cookies.
      StreamResolver.instance.clearCache();
      _poll?.cancel();
      if (mounted) {
        setState(() => _status =
            'Accesso effettuato${info != null ? ' come ${info['name']}' : ''}.');
        context.go('/');
      }
    } catch (e) {
      if (!fromPoll && mounted) setState(() => _error = 'Import fallito: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _pasteCookies() async {
    final raw = _cookieController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Incolla prima il cookie dal browser.');
      return;
    }
    try {
      final count = await CookieStore.instance.importCookieHeader(raw);
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
      if (!mounted) return;
      setState(() => _status = 'Importati $count cookie.');
      context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = 'Import cookie fallito: $e');
    }
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Accedi con Google',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Si aprirà una finestra del browser dedicata. Dopo il login '
                "l'app rileverà automaticamente la sessione e tornerà alla home.",
              ),
              const SizedBox(height: 24),
              if (_opening)
                const LinearProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _openBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri il browser e accedi'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _checking ? null : () => _tryImport(),
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
              const Text(
                'Fallback — incolla qui l\'header Cookie copiato da DevTools',
                style: TextStyle(fontSize: 12),
              ),
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
  // Kept in a helper so the UI file does not import path_provider directly.
  final dir = Directory('${Platform.environment['LOCALAPPDATA']}\\com.echo\\Echo Music');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}
