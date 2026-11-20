import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Robust Google/YouTube sign-in for desktop via Chrome/Edge DevTools
/// Protocol. Uses the *browser-level* target (`/json/version` +
/// `Storage.getCookies`) so cookie capture does not depend on which tab is
/// active or its URL — a common cause of "login does nothing".
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

  /// Pure: filter CDP cookies and report whether a real auth cookie exists.
  static ({Map<String, String> pairs, bool hasAuth}) collect(
    List<Map<String, dynamic>> cookies,
  ) {
    final pairs = <String, String>{};
    var hasAuth = false;
    for (final c in cookies) {
      final name = c['name']?.toString() ?? '';
      final value = c['value']?.toString() ?? '';
      final domain = c['domain']?.toString() ?? '';
      if (!isAllowedDomain(domain)) continue;
      if (authCookies.contains(name)) hasAuth = true;
      if (name.isNotEmpty && value.isNotEmpty) pairs[name] = value;
    }
    return (pairs: pairs, hasAuth: hasAuth);
  }

  /// Launch a browser with remote debugging. `--remote-allow-origins=*` is
  /// required by Chrome 111+ for the WebSocket CDP connection to succeed.
  Future<bool> openBrowser({
    required String profileDir,
    List<String>? executables,
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
      _browser = await Process.start(exe, [
        '--remote-debugging-port=$port',
        '--remote-allow-origins=*',
        '--user-data-dir=$profileDir',
        '--no-first-run',
        '--no-default-browser-check',
        loginUrl,
      ]);
      return true;
    } catch (e) {
      debugPrint('[google-login] launch failed: $e');
      return false;
    }
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

  /// Poll until a real sign-in cookie appears, then return filtered pairs.
  Future<Map<String, String>?> waitForSignIn({
    required Duration timeout,
    required Future<bool> Function() cancelled,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (await cancelled()) return null;
      final cookies = await readCookies();
      if (cookies != null) {
        final collected = collect(cookies);
        if (collected.hasAuth && collected.pairs.isNotEmpty) {
          return collected.pairs;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  void closeBrowser() {
    _browser?.kill();
    _browser = null;
  }
}
