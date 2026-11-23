import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'automix_debug.dart';
import 'google_login_service.dart';

/// Port of Echo Android's `PoTokenGenerator` / `PoTokenWebView`: mints a
/// BotGuard PoToken locally in the already-running debug browser, with no
/// login and no user interaction. This is the fix mobile uses for age-gated
/// tracks (desktop previously relied on sniffing Chrome's network).
class PoTokenMinter {
  PoTokenMinter._();

  static final PoTokenMinter instance = PoTokenMinter._();

  static const requestKey = 'O43z0dpjhgX20SCx4KAo';
  static const apiKey = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
  static const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.3';
  static const createUrl = 'https://www.youtube.com/api/jnn/v1/Create';
  static const generateItUrl =
      'https://www.youtube.com/api/jnn/v1/GenerateIT';

  final http.Client _client = http.Client();
  Map<String, dynamic>? _challenge;
  String? _identifier;
  DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);
  String? _script;
  _Cdp? _cdp;

  bool get isInitialized => _challenge != null && DateTime.now().isBefore(_expiry);

  void invalidate() {
    _challenge = null;
    _identifier = null;
    _expiry = DateTime.fromMillisecondsSinceEpoch(0);
    _cdp = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json+protobuf',
        'Accept': 'application/json',
        'x-goog-api-key': apiKey,
        'x-user-agent': 'grpc-web-javascript/0.1',
        'User-Agent': userAgent,
      };

  /// Descramble: base64-decode the challenge string, then add 97 to each byte.
  static Uint8List descramble(String scrambled) {
    final raw = base64.decode(scrambled);
    return Uint8List.fromList(raw.map((b) => (b + 97) & 0xff).toList());
  }

  /// YouTube-style base64: '-'->'+', '_'->'/', '.'->'='.
  static Uint8List youTubeBase64(String value) {
    var normalized = value
        .replaceAll('-', '+')
        .replaceAll('_', '/')
        .replaceAll('.', '=');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64.decode(normalized);
  }

  /// Base64 for PoTokens (URL-safe alphabet).
  static String poTokenToBase64(List<int> bytes) =>
      base64Encode(bytes).replaceAll('+', '-').replaceAll('/', '_');

  /// Parses the Create response into the shape po_token.html expects.
  static Map<String, dynamic> parseChallenge(String body) {
    final raw = jsonDecode(body) as List<dynamic>;
    final List<dynamic> data;
    if (raw.length > 1 && raw[1] is String) {
      data = jsonDecode(utf8.decode(descramble(raw[1] as String))) as List<dynamic>;
    } else {
      data = raw[0] as List<dynamic>;
    }
    String? firstString(dynamic value) {
      if (value is String) return value.isEmpty ? null : value;
      if (value is! List) return null;
      for (final item in value) {
        if (item is String && item.isNotEmpty) return item;
      }
      return null;
    }

    return {
      'messageId': data[0].toString(),
      'interpreterJavascript': {
        'privateDoNotAccessOrElseSafeScriptWrappedValue': firstString(data[1]),
        'privateDoNotAccessOrElseTrustedResourceUrlWrappedValue':
            firstString(data[2]),
      },
      'interpreterHash': data[3].toString(),
      'program': data[4].toString(),
      'globalName': data[5].toString(),
      'clientExperimentsStateBlob': data[7].toString(),
    };
  }

  /// Mints a session-bound token for [identifier] (visitorData / dataSyncId).
  Future<String?> mint(String identifier) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (!isInitialized || _identifier != identifier || attempt > 0) {
          await _initialize(identifier, force: attempt > 0);
        }
        final bytes = utf8.encode(identifier);
        final value = await _cdp!.evaluate(
          '(async () => { const t = await window.__echoBotGuard'
          '.obtainPoToken(new Uint8Array([${bytes.join(',')}])); '
          'return Array.from(t); })()',
        );
        if (value is! List || value.isEmpty) {
          throw Exception('token vuoto');
        }
        final token = poTokenToBase64(value.cast<int>());
        AutomixDebug.instance.log(
          'PoToken locale generato (${token.length} char, '
          'id=${identifier.length}, tentativo ${attempt + 1})',
        );
        return token;
      } catch (e) {
        lastError = e;
        invalidate();
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    AutomixDebug.instance.log('PoToken mint fallito: $lastError', level: 'ERROR');
    return null;
  }

  Future<void> _initialize(String identifier, {bool force = false}) async {
    if (force) invalidate();
    final create = await _client
        .post(
          Uri.parse(createUrl),
          headers: _headers,
          body: jsonEncode([requestKey]),
        )
        .timeout(const Duration(seconds: 15));
    if (create.statusCode != 200) {
      throw Exception('BotGuard Create HTTP ${create.statusCode}');
    }
    _challenge = parseChallenge(create.body);
    final js = _challenge!['interpreterJavascript'] as Map<String, dynamic>;
    if (js['privateDoNotAccessOrElseSafeScriptWrappedValue'] == null) {
      throw Exception('challenge senza interpreter JavaScript');
    }

    final cdp = await _ensureBrowser();
    _cdp = cdp;
    // BotGuard expects a real youtube.com page context.
    await cdp.call('Page.navigate', {'url': 'https://www.youtube.com/'});
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final script = await loadScript();
    await cdp.evaluate('window.__echoBotGuard = (function(){ $script '
        'return { runBotGuard: runBotGuard, '
        'createPoTokenMinter: createPoTokenMinter, '
        'obtainPoToken: obtainPoToken }; })(); true');

    final botguardResponse = await cdp.evaluate(
      '(async () => { window.__echoBg = await window.__echoBotGuard'
      '.runBotGuard(${jsonEncode(_challenge)}); '
      'return window.__echoBg.botguardResponse; })()',
    );
    if (botguardResponse is! String || botguardResponse.isEmpty) {
      throw Exception('BotGuard response vuota');
    }

    final it = await _client
        .post(
          Uri.parse(generateItUrl),
          headers: _headers,
          body: jsonEncode([requestKey, botguardResponse]),
        )
        .timeout(const Duration(seconds: 20));
    if (it.statusCode != 200) {
      throw Exception('BotGuard GenerateIT HTTP ${it.statusCode}');
    }
    final data = jsonDecode(it.body) as List<dynamic>;
    final tokenBytes = youTubeBase64(data[0].toString());
    final ttl = (data[1] is num ? (data[1] as num).toInt() : 3600);
    _expiry = DateTime.now()
        .add(Duration(seconds: ttl))
        .subtract(const Duration(minutes: 10));

    await cdp.evaluate(
      '(async () => { await window.__echoBotGuard.createPoTokenMinter('
      'window.__echoBg.webPoSignalOutput, '
      'new Uint8Array([${tokenBytes.join(',')}])); return true; })()',
    );
    _identifier = identifier;
  }

  Future<_Cdp> _ensureBrowser() async {
    final login = GoogleLoginService();
    if (!await GoogleLoginService.isCdpUp(login.port)) {
      final profile = await GoogleLoginService.profileDirectory();
      await login.openBrowser(
        profileDir: profile.path,
        url: 'https://www.youtube.com/',
      );
      for (var i = 0;
          i < 40 && !await GoogleLoginService.isCdpUp(login.port);
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final wsUrl = await login.pageWebSocketUrl('youtube.com') ??
        await login.pageWebSocketUrl('');
    if (wsUrl == null) throw Exception('Browser CDP non disponibile');
    return _Cdp.connect(wsUrl);
  }

  /// Loads the bundled BotGuard JS once.
  Future<String> loadScript() async {
    final script = _script ??=
        await rootBundle.loadString('assets/po/po_token.html');
    final start = script.indexOf('<script>');
    final end = script.lastIndexOf('</script>');
    if (start < 0 || end < 0) return script;
    return script.substring(start + '<script>'.length, end);
  }
}

/// Minimal CDP client for Runtime.evaluate over the browser page websocket.
class _Cdp {
  _Cdp(this._ws) {
    _ws.listen((message) {
      try {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        final id = decoded['id'];
        if (id is int) _pending.remove(id)?.complete(decoded);
      } catch (_) {}
    });
  }

  final WebSocket _ws;
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  static Future<_Cdp> connect(String url) async =>
      _Cdp(await WebSocket.connect(url).timeout(const Duration(seconds: 5)));

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(jsonEncode({
      'id': id,
      'method': method,
      'params': params,
    }));
    try {
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }

  Future<dynamic> evaluate(String expression) async {
    final response = await call('Runtime.evaluate', {
      'expression': expression,
      'awaitPromise': true,
      'returnByValue': true,
    });
    final exception = response['result']?['exceptionDetails'];
    if (exception != null) {
      throw Exception(exception['text'] ?? exception.toString());
    }
    return response['result']?['result']?['value'];
  }
}
