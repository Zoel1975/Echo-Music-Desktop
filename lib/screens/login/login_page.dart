import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/account_refresh.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/google_login_service.dart';
import 'package:Echo/services/stream_resolver.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Google sign-in for YouTube Music on desktop. Opens the system browser with
/// remote debugging, waits for a real Google auth cookie, imports it into the
/// app and returns home — no manual cookie copying.
///
/// Pure login logic lives in [GoogleLoginService]; this widget only drives
/// UI state. A manual cookie-paste fallback is kept for locked-down browsers.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, GoogleLoginService? service})
      : _serviceOverride = service;

  /// Injectable for tests; production uses the real CDP service.
  final GoogleLoginService? _serviceOverride;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final GoogleLoginService _service =
      widget._serviceOverride ?? GoogleLoginService();
  final _cookieController = TextEditingController();
  Timer? _timeout;
  Timer? _diagTimer;
  bool _opening = false;
  bool _checking = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-refresh diagnostics every 2s so the user sees the state live.
    _diagTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshDiag());
    _refreshDiag();
  }

  ({String text, Color color, bool isError}) _diag =
      (text: 'Stato login non disponibile', color: Colors.grey, isError: false);

  void _refreshDiag() {
    unawaited(_updateDiag());
  }

  Future<void> _updateDiag() async {
    final d = await _service.diagnostics();
    if (!mounted) return;
    final cdpUp = d.cookieCount > 0 || await GoogleLoginService.isCdpUp(_service.port);
    if (!mounted) return;
    setState(() {
      final names = d.cookieNames.isEmpty
          ? '—'
          : d.cookieNames.take(6).join(', ') +
              (d.cookieNames.length > 6 ? '…' : '');
      final sessionOk = CookieStore.instance.dataSyncId != null;
      _diag = (
        text: 'Browser: ${d.browserVersion ?? GoogleLoginService.findBrowser()?.split('\\').last ?? "nessun Chrome/Edge"} · '
            'CDP: ${cdpUp ? 'on' : 'off'} · Cookie: ${d.cookieCount} · '
            '${d.hasAuth ? 'ACCREDENTI PRESENTI' : 'nessuna credenziale'}\n'
            'Cookie visti: $names\n'
            'ID account: ${sessionOk ? 'datasync ok' : 'datasync assente'}',
        color: d.hasAuth
            ? Colors.green
            : cdpUp ? Colors.orange : Colors.red,
        isError: !d.hasAuth,
      );
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _diagTimer?.cancel();
    _service.closeBrowser();
    _cookieController.dispose();
    super.dispose();
  }

  Future<String> _profileDir() async {
    final dir = await GoogleLoginService.profileDirectory();
    return dir.path;
  }

  /// Port of Android's `processSuccessfulAuth`: store the cookie, the account
  /// ids from the page (`VISITOR_DATA` / `DATASYNC_ID`), validate the session
  /// with `account/account_menu`, persist the account and go home.
  Future<void> _finishLogin(LoginCapture capture) async {
    final pairs = capture.cookies;
    await CookieStore.instance.importCookieHeader(
        pairs.entries.map((e) => '${e.key}=${e.value}').join('; '));

    final YTMusic yt = GetIt.I<YTMusic>();

    // The page shell may still be loading when the cookie appears: wait for
    // `window.yt.config_.DATASYNC_ID` before giving up on the account id.
    var session = capture.session;
    if (session?.dataSyncId == null &&
        await GoogleLoginService.isCdpUp(_service.port)) {
      session = await _service.waitForSessionState() ?? session;
    }

    // 1. Account id first: `user.onBehalfOfUser` is required by the library
    //    endpoints and by `account/account_menu`.
    await CookieStore.instance.saveDataSyncId(session?.dataSyncId);

    // 2. Account-bound visitor id (Android stores `VISITOR_DATA` too).
    final settings = Hive.box('SETTINGS');
    final pageVisitor = session?.visitorData;
    if (pageVisitor != null && pageVisitor.isNotEmpty) {
      await settings.put('VISITOR_ID', pageVisitor);
      yt.config = (yt.config ??
              YTConfig(visitorData: '', language: 'en', location: 'IN'))
          .copyWith(visitorData: pageVisitor);
    }

    try {
      // 3. The client was created at startup with the ANONYMOUS visitor id.
      //    Ask music.youtube.com for the id bound to this session when the
      //    page did not expose one (manual cookie paste, or page still
      //    loading).
      if (pageVisitor == null || pageVisitor.isEmpty) {
        await yt.resetVisitorId();
      }
      await yt.refreshHeaders();
    } catch (_) {}

    Map<String, dynamic>? info;
    try {
      info = await yt.getAccountInfo();
    } catch (_) {}
    await CookieStore.instance.saveAccount({
      'name': info?['name'] ?? 'YouTube Music',
      if (info != null) ...info,
      'signedIn': true,
    });
    StreamResolver.instance.clearCache();
    notifyAccountChanged();
    _service.closeBrowser();
    if (mounted) {
      setState(() => _status = info?['name'] != null
          ? 'Accesso effettuato come ${info!['name']}.'
          : 'Accesso effettuato.');
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

    final capture = await _service.waitForSignIn(
      timeout: const Duration(minutes: 5),
      cancelled: () async => !mounted,
      verifySession: _verifySession,
    );
    _timeout?.cancel();
    if (capture != null && mounted) {
      await _finishLogin(capture);
    } else if (mounted) {
      setState(() {
        _error = 'Cookie di accesso non rilevati. Riprova o incolla il cookie.';
        _status = null;
      });
    }
  }

  /// Fallback session check via the YouTube Music account endpoint: if Google
  /// renames auth cookies, the API still tells us whether we are signed in.
  Future<bool> _verifySession(Map<String, String> cookies) async {
    final plausible = cookies.keys.any((k) =>
        k.contains('SID') || k.contains('APISID') || k == 'LOGIN_INFO');
    if (!plausible) return false;
    try {
      await CookieStore.instance.importCookieHeader(
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      final info = await GetIt.I<YTMusic>().getAccountInfo();
      return info != null && info['name']?.toString().isNotEmpty == true;
    } catch (_) {
      return false;
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
    // A google.com-only session is not enough: YouTube Music reads its own
    // cookie jar, so require a youtube.com auth cookie (or confirm with the
    // real account endpoint) before saving anything.
    if (collected != null &&
        collected.pairs.isNotEmpty &&
        (collected.youtubeAuth || await _verifySession(collected.pairs))) {
      final session = await _service.readSessionState();
      await _finishLogin(
        LoginCapture(cookies: collected.pairs, session: session),
      );
    } else {
      setState(() {
        _checking = false;
        _error = collected != null && collected.hasAuth
            ? 'Accesso Google presente, ma YouTube Music non è ancora '
                'autenticato: apri music.youtube.com nel browser e completa '
                'il login.'
            : 'Nessun cookie di accesso trovato. Fai il login nel browser.';
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
    await _finishLogin(
      LoginCapture(cookies: CookieStore.parseCookieHeader(raw)),
    );
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
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _diag.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: _diag.isError ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aggiorna diagnostica',
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshDiag,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
