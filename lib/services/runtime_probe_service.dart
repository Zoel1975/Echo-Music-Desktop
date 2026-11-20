import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'account_refresh.dart';
import 'audio_fallback.dart';
import 'cookie_store.dart';
import 'session_service.dart';
import '../utils/router.dart' as app_router;
import '../ytmusic/ytmusic.dart';

/// Loopback-only diagnostic server, enabled explicitly with `ECHO_DIAG=1`.
///
/// It exists so sign-out / session state can be verified in the *running*
/// desktop process (unit tests only see the code, not the app). It is never
/// started in a normal launch and never binds to a network interface.
class RuntimeProbeService {
  RuntimeProbeService._();

  static Future<HttpServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await _handle(request);
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
    });
    debugPrint('[runtime-probe] http://127.0.0.1:${server.port}');
    // ignore: avoid_print
    print('RUNTIME_PROBE_URL=http://127.0.0.1:${server.port}');
    return server;
  }

  static void _json(HttpResponse response, int status, Object body) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }

  static Map<String, dynamic> state() {
    final account = CookieStore.instance.account;
    return {
      'signedIn': CookieStore.instance.cookieHeader != null,
      'cookieNames': CookieStore.instance.cookies.keys.toList()..sort(),
      'hasSapisid': CookieStore.instance.cookies.containsKey('SAPISID'),
      'dataSyncId': CookieStore.instance.dataSyncId,
      'accountName': account['name'],
      'accountEmpty': account.isEmpty,
      'accountEpoch': accountEpoch.value,
      'visitorId': Hive.isBoxOpen('SETTINGS')
          ? Hive.box('SETTINGS').get('VISITOR_ID') != null
          : null,
      'audioFallback': audioFallback.value,
    };
  }

  static Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/state' && request.method == 'GET') {
      _json(request.response, 200, state());
      return;
    }
    if (path == '/signout' && request.method == 'POST') {
      // Exactly the call made by AccountPage's "Sign out" tile.
      await SessionService().signOut();
      _json(request.response, 200, {'after': state()});
      return;
    }
    if (path == '/seed' && request.method == 'POST') {
      // Only for testing: fabricate a session so sign-out has something to
      // remove. No real Google credentials are involved.
      await CookieStore.instance.importCookieHeader(
        'SAPISID=probe-sapisid; SID=probe-sid; LOGIN_INFO=probe',
      );
      await CookieStore.instance
          .saveAccount({'name': 'Probe User', 'signedIn': true});
      await CookieStore.instance.saveDataSyncId('PROBE_DATASYNC');
      if (Hive.isBoxOpen('SETTINGS')) {
        await Hive.box('SETTINGS').put('VISITOR_ID', 'PROBE_VISITOR');
      }
      notifyAccountChanged();
      _json(request.response, 200, {'after': state()});
      return;
    }
    if (path == '/goto' && request.method == 'POST') {
      final route = request.uri.queryParameters['path'] ?? '/';
      app_router.router.go(route);
      _json(request.response, 200, {'route': route});
      return;
    }
    if (path == '/library' && request.method == 'GET') {
      final signedIn = CookieStore.instance.cookieHeader != null;
      try {
        final res = await GetIt.I<YTMusic>().getLibraryPlaylists();
        _json(request.response, 200, {
          'signedIn': signedIn,
          'contents': (res['contents'] as List?)?.length ?? 0,
          'continuation': res['continuation']?.toString(),
        });
      } catch (e) {
        _json(request.response, 200, {
          'signedIn': signedIn,
          'error': e.toString(),
        });
      }
      return;
    }
    _json(request.response, 404, {'error': 'unknown endpoint', 'path': path});
  }
}
