import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Port of Android `JellyfinScreens.kt` / `NavidromeScreens.kt`: verifies
/// server connectivity with credentials entered in-app.
class CloudService {
  CloudService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Pure: build a Jellyfin authentication header value.
  static String jellyfinAuth({required String user, required String password}) =>
      'MediaBrowser UserId="$user", Client="EchoMusic", '
      'Device="Desktop", Version="1.0", Token="$password"';

  /// Pure: normalize a base URL (strip trailing slash).
  static String normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Pure: parse Navidrome ping response into a boolean.
  static bool parseNavidromePing(Map<String, dynamic> json) =>
      json['status']?.toString().toLowerCase() == 'ok';

  Future<bool> checkJellyfin({
    required String url,
    required String user,
    required String password,
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) return false;
    try {
      final r = await _client
          .get(
            Uri.parse('$normalized/System/Info/Public'),
            headers: {'X-Emby-Authorization': jellyfinAuth(user: user, password: password)},
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('[cloud] jellyfin check failed: $e');
      return false;
    }
  }

  Future<bool> checkNavidrome({
    required String url,
    required String user,
    required String password,
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) return false;
    final basic = base64.encode(utf8.encode('$user:$password'));
    try {
      final r = await _client
          .get(
            Uri.parse('$normalized/rest/ping.view?u=$user&f=json'),
            headers: {'Authorization': 'Basic $basic'},
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return false;
      return parseNavidromePing(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[cloud] navidrome check failed: $e');
      return false;
    }
  }
}
