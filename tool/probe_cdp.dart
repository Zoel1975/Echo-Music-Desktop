import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final profile =
      Directory('${Directory.systemTemp.path}\\echo-probe-${DateTime.now().millisecondsSinceEpoch}');
  final chrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  final p = await Process.start(chrome, [
    '--remote-debugging-port=9553', '--remote-allow-origins=*',
    '--user-data-dir=$profile', '--no-first-run', '--no-default-browser-check',
    'about:blank',
  ]);
  for (var i = 0; i < 40; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final done = await http
          .get(Uri.parse('http://127.0.0.1:9553/json/version'))
          .timeout(const Duration(milliseconds: 500));
      if (done.statusCode == 200) break;
    } catch (_) {}
  }
  print('alive=${p.exitCode == null}');

  final list = await http
      .get(Uri.parse('http://127.0.0.1:9553/json/list'))
      .timeout(const Duration(seconds: 3));
  final targets = jsonDecode(list.body) as List;
  print('targets: ${targets.map((t) => t['type']).toList()}');
  final page = targets.firstWhere((t) => t['type'] == 'page');
  final wsUrl = page['webSocketDebuggerUrl'] as String;
  print('page ws: $wsUrl');

  final ws = await WebSocket.connect(wsUrl);
  int id = 0;
  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> params) async {
    final m = jsonEncode({'id': ++id, 'method': method, 'params': params});
    ws.add(m);
    await for (final msg in ws) {
      final d = jsonDecode(msg as String) as Map<String, dynamic>;
      if (d['id'] == id) return d;
    }
    throw StateError('no response for $method');
  }

  final tryCalls = [
    'Page.getNavigationHistory',
    'Storage.setCookie',
    'Network.setCookie',
    'Storage.setCookies',
  ];
  for (final method in tryCalls) {
    final d = await call(method, {
      'url': 'https://www.youtube.com/',
      'name': 'SAPISID',
      'value': 'FAKESAPISID',
    });
    print('$method -> ${d['result'] != null ? 'OK' : 'ERR ${d['error']}'}');
  }
  final cookies = await call('Storage.getCookies', {});
  print('Storage.getCookies -> ${(cookies['result'] as Map?)?['cookies'].length} cookies');
  await ws.close();
  p.kill();
  await Future.delayed(const Duration(milliseconds: 500));
  profile.deleteSync(recursive: true);
}
