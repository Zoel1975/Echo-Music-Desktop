import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'yt_session.dart';

/// What a successful sign-in detection returns: the cookies to import plus the
/// account ids read from the YouTube Music page (Android reads the same values
/// from `window.yt.config_` inside its WebView).
class LoginCapture {
  const LoginCapture({required this.cookies, this.session});

  final Map<String, String> cookies;
  final YtSession? session;

  String? get visitorData => session?.visitorData;
  String? get dataSyncId => session?.dataSyncId;
}

/// Robust Google/YouTube sign-in for desktop via Chrome/Edge DevTools
/// Protocol. Uses the *browser-level* target (`/json/version` +
/// `Storage.getCookies`) so cookie capture does not depend on which tab is
/// active or its URL - a common cause of "login does nothing".
class GoogleLoginService {
  GoogleLoginService({this.port = 9333, http.Client? client})
      : _client = client ?? http.Client();

  final int port;
  final http.Client _client;
  Process? _browser;

  static const authCookies = {
    'SID',
    'HSID',
    'SSID',
    'APISID',
    'SAPISID',
    '__Secure-3PAPISID',
    '__Secure-1PAPISID',
    '__Secure-3PSID',
    '__Secure-1PSID',
    'LOGIN_INFO',
  };
  static const allowedDomains = [
    'youtube.com',
    'google.com',
    'gstatic.com',
    'googleusercontent.com',
    'googleapis.com',
  ];

  static const loginUrl =
      'https://accounts.google.com/ServiceLogin?service=youtube'
      '&continue=https%3A%2F%2Fmusic.youtube.com%2F';

  /// Pure: is this cookie a Google/YouTube host cookie?
  static bool isAllowedDomain(String domain) {
    final d = domain.toLowerCase();
    return allowedDomains.any((a) => d == a || d.endsWith('.$a'));
  }

  /// Pure: is this cookie scoped to youtube.com (where Music reads them)?
  static bool isYoutubeDomain(String domain) {
    final d = domain.toLowerCase();
    return d == 'youtube.com' || d.endsWith('.youtube.com');
  }

  /// Pure: filter CDP cookies and report whether a real auth cookie exists.
  ///
  /// Android reads `CookieManager.getCookie("https://music.youtube.com")`,
  /// i.e. ONLY the youtube.com cookies. Merging `.google.com` cookies is wrong:
  /// they use the same names (`SAPISID`, `SID`, `__Secure-3PSID`, ...) with
  /// different values, so a google.com `SAPISID` overwrote YouTube's one and
  /// the `SAPISIDHASH` built from it was rejected - login looked fine but the
  /// library came back empty.
  static ({Map<String, String> pairs, bool hasAuth}) collect(
    List<Map<String, dynamic>> cookies,
  ) {
    final youtube = <String, String>{};
    final other = <String, String>{};
    var youtubeAuth = false;
    var otherAuth = false;
    for (final c in cookies) {
      final name = c['name']?.toString() ?? '';
      final value = c['value']?.toString() ?? '';
      final domain = c['domain']?.toString() ?? '';
      if (!isAllowedDomain(domain)) continue;
      if (name.isEmpty || value.isEmpty) continue;
      final isAuth = authCookies.contains(name);
      if (isYoutubeDomain(domain)) {
        youtube[name] = value;
        if (isAuth) youtubeAuth = true;
      } else {
        other[name] = value;
        if (isAuth) otherAuth = true;
      }
    }
    // Prefer YouTube's own cookie jar whenever it carries a session; only fall
    // back to the merged set when YouTube has not been visited yet.
    final pairs = youtubeAuth
        ? youtube
        : <String, String>{...other, ...youtube};
    return (pairs: pairs, hasAuth: youtubeAuth || otherAuth);
  }

  /// Launch a browser with remote debugging. `--remote-allow-origins=*` is
  /// required by Chrome 111+ for the WebSocket CDP connection to succeed.
  Future<bool> openBrowser({
    required String profileDir,
    List<String>? executables,
    String url = loginUrl,
  }) async {
    final candidates = executables ?? [
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    ];
    String? exe;
    for (final c in candidates) {
      if (File(c).existsSync()) {
        exe = c;
        break;
      }
    }
    if (exe == null) return false;
    try {
      // Start on a blank page so we can accept the Google/YouTube consent
      // cookies BEFORE the real page loads. A fresh profile otherwise lands on
      // `consent.youtube.com` ("Prima di continuare"), where `window.yt` does
      // not exist and no youtube.com cookie is ever created - the login would
      // appear to do nothing.
      _browser = await Process.start(exe, [
        '--remote-debugging-port=$port',
        '--remote-allow-origins=*',
        '--user-data-dir=$profileDir',
        '--no-first-run',
        '--no-default-browser-check',
        '--lang=en-US',
        'about:blank',
      ]);
      await _bootstrap(url, profileDir);
      return true;
    } catch (e) {
      debugPrint('[google-login] launch failed: $e');
      return false;
    }
  }

  /// Consent cookies that make YouTube/Google skip the interstitial.
  /// `SOCS=CAI` is the modern one, `CONSENT=YES+1` the legacy fallback.
  static const consentCookies = <({String name, String value, String domain})>[
    (name: 'SOCS', value: 'CAI', domain: '.youtube.com'),
    (name: 'SOCS', value: 'CAI', domain: '.google.com'),
    (name: 'CONSENT', value: 'YES+1', domain: '.youtube.com'),
    (name: 'CONSENT', value: 'YES+1', domain: '.google.com'),
  ];

  /// Waits for the first page target, sets consent cookies over CDP and then
  /// navigates to [url]. Best effort: on any failure the browser is opened with
  /// [url] as a plain command-line argument instead.
  Future<void> _bootstrap(String url, String profileDir) async {
    final wsUrl = await _waitForPageTarget();
    if (wsUrl == null) {
      await _reopenWithUrl(url, profileDir);
      return;
    }
    WebSocket? ws;
    StreamSubscription<dynamic>? sub;
    final pending = <int, Completer<Map<String, dynamic>?>>{};
    var nextId = 100;
    try {
      ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      sub = ws.listen((message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final id = decoded['id'];
          if (id is int) pending.remove(id)?.complete(decoded);
        } catch (_) {}
      });

      Future<Map<String, dynamic>?> call(
        String method, [
        Map<String, dynamic>? params,
      ]) {
        final id = nextId++;
        final c = Completer<Map<String, dynamic>?>();
        pending[id] = c;
        ws!.add(jsonEncode({
          'id': id,
          'method': method,
          if (params != null) 'params': params,
        }));
        return c.future
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      }

      await call('Network.enable');
      for (final c in consentCookies) {
        await call('Network.setCookie', {
          'name': c.name,
          'value': c.value,
          'domain': c.domain,
          'path': '/',
          'secure': true,
          'sameSite': 'None',
        });
      }
      await call('Page.navigate', {'url': url});
    } catch (e) {
      debugPrint('[google-login] bootstrap failed: $e');
      await _reopenWithUrl(url, profileDir);
    } finally {
      await sub?.cancel();
      await ws?.close();
    }
  }

  /// Fallback: open [url] through the browser executable (a second launch with
  /// the same profile opens a tab in the running instance).
  Future<void> _reopenWithUrl(String url, String profileDir) async {
    final exe = findBrowser();
    if (exe == null) return;
    try {
      await Process.start(exe, [
        '--remote-debugging-port=$port',
        '--remote-allow-origins=*',
        '--user-data-dir=$profileDir',
        '--no-first-run',
        '--no-default-browser-check',
        url,
      ]);
    } catch (e) {
      debugPrint('[google-login] reopen failed: $e');
    }
  }

  Future<String?> _waitForPageTarget() async {
    for (var i = 0; i < 24; i++) {
      final ws = await _pageWebSocketUrl('');
      if (ws != null) return ws;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  /// Pure: the browser executable we will launch, or null if none found.
  static String? findBrowser() {
    const candidates = [
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Dedicated browser profile used for the Google sign-in flow.
  static Directory profileDirectorySync() {
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory('$base\\com.echo\\Echo Music\\login-browser');
  }

  static Future<Directory> profileDirectory() async {
    final dir = profileDirectorySync();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Sign out the login browser too.
  ///
  /// Android clears the WebView cookies with
  /// `cookieManager.removeAllCookies(null)`, so "forget account" also forgets
  /// the Google session. The desktop equivalent is deleting the dedicated
  /// profile directory (the app's own session lives elsewhere).
  static Future<void> clearProfile() async {
    final dir = profileDirectorySync();
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[google-login] could not clear profile: $e');
    }
  }

  /// Pure: is the remote-debugging endpoint answering on [port]?
  static Future<bool> isCdpUp(int port) async {
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:$port/json/version'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Diagnostics: count of Google/YouTube cookies, whether a real auth cookie
  /// is present, the names seen, and the browser/CDP version string.
  Future<({
    int cookieCount,
    bool hasAuth,
    List<String> cookieNames,
    String? browserVersion,
  })> diagnostics() async {
    final cookies = await readCookies();
    String? version;
    try {
      final r = await _client
          .get(Uri.parse('http://127.0.0.1:$port/json/version'))
          .timeout(const Duration(seconds: 2));
      if (r.statusCode == 200) {
        version = (jsonDecode(r.body) as Map<String, dynamic>)['Browser'] as String?;
      }
    } catch (_) {}
    if (cookies == null) {
      return (
        cookieCount: 0,
        hasAuth: false,
        cookieNames: const <String>[],
        browserVersion: version,
      );
    }
    final collected = collect(cookies);
    final names = collected.pairs.keys.toList()..sort();
    return (
      cookieCount: collected.pairs.length,
      hasAuth: collected.hasAuth,
      cookieNames: names,
      browserVersion: version,
    );
  }

  /// Read the browser-level WebSocket debugger URL from /json/version.
  Future<String?> _browserWebSocketUrl() async {
    try {
      final r = await _client
          .get(Uri.parse('http://127.0.0.1:$port/json/version'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return data['webSocketDebuggerUrl'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// WebSocket URL of the first page whose URL contains [contains].
  Future<String?> _pageWebSocketUrl(String contains) async {
    try {
      final r = await _client
          .get(Uri.parse('http://127.0.0.1:$port/json/list'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) return null;
      final list = jsonDecode(r.body) as List<dynamic>;
      String? fallback;
      for (final t in list.whereType<Map<String, dynamic>>()) {
        final url = t['url']?.toString() ?? '';
        final ws = t['webSocketDebuggerUrl']?.toString();
        if (ws == null || !url.contains(contains)) continue;
        if (t['type']?.toString() == 'page') return ws;
        fallback ??= ws;
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all cookies via browser-level `Storage.getCookies`.
  Future<List<Map<String, dynamic>>?> readCookies() async {
    final wsUrl = await _browserWebSocketUrl();
    if (wsUrl == null) return null;
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      ws.add(jsonEncode({
        'id': 1,
        'method': 'Storage.getCookies',
      }));
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
    } catch (e) {
      debugPrint('[google-login] CDP read failed: $e');
    } finally {
      await ws?.close();
    }
    return null;
  }

  /// Port of Android's `onPageFinished` extraction:
  /// `window.yt.config_.VISITOR_DATA` and `window.yt.config_.DATASYNC_ID`
  /// read from the signed-in music.youtube.com page.
  Future<YtSession?> readSessionState() async {
    final wsUrl = await _pageWebSocketUrl('music.youtube.com');
    if (wsUrl == null) return null;
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      const expression = 'JSON.stringify({'
          'VISITOR_DATA:(window.yt&&window.yt.config_&&window.yt.config_.VISITOR_DATA)||null,'
          'DATASYNC_ID:(window.yt&&window.yt.config_&&window.yt.config_.DATASYNC_ID)||null,'
          'LOGGED_IN:!!(window.yt&&window.yt.config_&&window.yt.config_.LOGGED_IN)})';
      ws.add(jsonEncode({
        'id': 2,
        'method': 'Runtime.evaluate',
        'params': {
          'expression': expression,
          'returnByValue': true,
          'awaitPromise': false,
        },
      }));
      await for (final message in ws.timeout(const Duration(seconds: 5))) {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        if (decoded['id'] != 2) continue;
        final value = decoded['result']?['result']?['value'];
        if (value is! String || value.isEmpty) return null;
        final map = jsonDecode(value) as Map<String, dynamic>;
        return YtSession.fromBrowserConfig(map);
      }
    } catch (e) {
      debugPrint('[google-login] session read failed: $e');
    } finally {
      await ws?.close();
    }
    return null;
  }

  /// Poll until a real sign-in cookie appears, then return the cookies plus the
  /// account ids from the page. [verifySession] optionally confirms the session
  /// with a real API call - useful if Google changes auth cookie names.
  Future<LoginCapture?> waitForSignIn({
    required Duration timeout,
    required Future<bool> Function() cancelled,
    Future<bool> Function(Map<String, String> cookies)? verifySession,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (await cancelled()) return null;
      final cookies = await readCookies();
      if (cookies != null) {
        final collected = collect(cookies);
        if (collected.pairs.isNotEmpty) {
          if (collected.hasAuth) {
            return LoginCapture(
              cookies: collected.pairs,
              session: await readSessionState(),
            );
          }
          // Auth cookie names may change: confirm with a real API call.
          if (verifySession != null && await verifySession(collected.pairs)) {
            return LoginCapture(
              cookies: collected.pairs,
              session: await readSessionState(),
            );
          }
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// Poll the page until it exposes `DATASYNC_ID`. After Google redirects to
  /// music.youtube.com the app shell loads asynchronously, so the first read
  /// usually happens before `window.yt.config_` exists.
  Future<YtSession?> waitForSessionState({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    YtSession? last;
    while (DateTime.now().isBefore(end)) {
      final s = await readSessionState();
      if (s != null) {
        last = s;
        if (s.dataSyncId != null) return s;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return last;
  }

  void closeBrowser() {
    _browser?.kill();
    _browser = null;
  }
}
