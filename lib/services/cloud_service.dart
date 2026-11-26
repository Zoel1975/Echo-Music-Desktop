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

  /// Android's cloud library sync: fetch the audio items from the configured
  /// server. The result is a plain song map list so callers can persist it.
  Future<List<Map<String, dynamic>>> fetchSongs({
    required String type,
    required String url,
    required String user,
    required String password,
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty || !(await (type == 'Jellyfin'
        ? checkJellyfin(url: url, user: user, password: password)
        : checkNavidrome(url: url, user: user, password: password)))) {
      return const [];
    }
    try {
      if (type == 'Jellyfin') {
        final r = await _client.get(
          Uri.parse('$normalized/Items?IncludeItemTypes=Audio&Recursive=true&Limit=500'),
          headers: {
            'X-Emby-Authorization': jellyfinAuth(user: user, password: password)
          },
        ).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) return const [];
        final items = (jsonDecode(r.body) as Map)['Items'];
        if (items is! List) return const [];
        return items.whereType<Map>().map((i) => <String, dynamic>{
          'videoId': 'jellyfin://${i['Id']}',
          'title': i['Name']?.toString() ?? 'Unknown',
          'artist': i['AlbumArtist']?.toString() ?? '',
          'album': i['Album']?.toString() ?? '',
        }).toList();
      }
      final basic = base64.encode(utf8.encode('$user:$password'));
      final r = await _client.get(
        Uri.parse('$normalized/rest/search3.view?u=$user&f=json&songCount=500'),
        headers: {'Authorization': 'Basic $basic'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const [];
      final songs = (jsonDecode(r.body) as Map)['subsonic-response']?['searchResult3']?['song'];
      if (songs is! List) return const [];
      return songs.whereType<Map>().map((i) => <String, dynamic>{
        'videoId': 'navidrome://${i['id']}',
        'title': i['title']?.toString() ?? 'Unknown',
        'artist': i['artist']?.toString() ?? '',
        'album': i['album']?.toString() ?? '',
      }).toList();
    } catch (e) {
      debugPrint('[cloud] sync failed: $e');
      return const [];
    }
  }
}
