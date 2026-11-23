import "package:hive_flutter/hive_flutter.dart";

/// Client identity that the Android app uses for YouTube Music.
/// Port of `YouTubeClient.WEB_REMIX` (`loginSupported = true`).
const String ytmClientName = 'WEB_REMIX';
const String ytmClientId = '67';
const String ytmOrigin = 'https://music.youtube.com';
const String ytmReferer = '$ytmOrigin/';

/// `WEB_REMIX` client version: `1.<yyyymmdd>.01.00`, exactly like Android.
String ytmClientVersion([DateTime? now]) {
  final d = now ?? DateTime.now();
  final year = d.year.toString();
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '1.$year$month$day.01.00';
}

Map<String, String> initializeHeaders({String language = 'en'}) {
  Map<String, String> h = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36 Edg/105.0.1343.42",
    'accept': '*/*',
    'accept-encoding': 'gzip, deflate',
    'content-type': 'application/json',
    // NOTE: no 'content-encoding: gzip' - request bodies are plain JSON.
    // Claiming gzip here makes YouTube reject every browse/search request.
    "Origin": ytmOrigin,
    // Headers Android's InnerTube always sends (`InnerTube.ytClient`).
    'X-Origin': ytmOrigin,
    'Referer': ytmReferer,
    'X-Goog-Api-Format-Version': '1',
    'X-YouTube-Client-Name': ytmClientId,
    'X-YouTube-Client-Version': ytmClientVersion(),
    'Cache-Control': 'no-cache',
    'cookie': 'CONSENT=YES+1',
    'Accept-Language': language,
  };

  return h;
}

/// Port of Android's `YouTubeClient.toContext`: the client block carries the
/// (account-bound) visitor id and `user.onBehalfOfUser` carries `dataSyncId`.
/// Without `dataSyncId` YouTube answers the library endpoints with an
/// anonymous/empty response even when the cookie is valid.
Map<String, dynamic> initializeContext() {
  final settings = Hive.box('SETTINGS');
  final visitorData = settings.get('VISITOR_ID')?.toString() ?? '';
  final dataSyncId = settings.get('DATASYNC_ID')?.toString() ?? '';
  return {
    'context': {
      'client': {
        // Android's ContentLanguage / ContentCountry control the YouTube
        // Music catalog locale, independent of the app UI language/region.
        "hl": settings.get('CONTENT_LANGUAGE')?.toString().isNotEmpty == true
            ? settings.get('CONTENT_LANGUAGE').toString()
            : settings.get('LANGUAGE', defaultValue: 'en-IN'),
        "gl": settings.get('CONTENT_COUNTRY')?.toString().isNotEmpty == true
            ? settings.get('CONTENT_COUNTRY').toString()
            : settings.get('LOCATION', defaultValue: 'IN'),
        'clientName': ytmClientName,
        'clientVersion': ytmClientVersion(),
        if (visitorData.isNotEmpty) 'visitorData': visitorData,
      },
      'user': <String, dynamic>{
        if (dataSyncId.isNotEmpty) 'onBehalfOfUser': dataSyncId,
      },
    }
  };
}

dynamic nav(dynamic root, List<dynamic> items, {bool noneIfAbsent = false}) {
  try {
    for (var k in items) {
      root = root?[k];
    }
    return root;
  } catch (err) {
    if (noneIfAbsent) {
      return null;
    } else {
      rethrow;
    }
  }
}

/// First `Map` found among [paths] inside [root], or an empty map.
///
/// Library endpoints sometimes omit the expected renderer (empty library,
/// changed response). The old `Map x = nav(...) ?? nav(...)` assigned `null`
/// to a non-nullable `Map` and threw
/// `type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'`.
Map firstMapOrEmpty(dynamic root, List<List<dynamic>> paths) {
  for (final path in paths) {
    final value = nav(root, path);
    if (value is Map) return value;
  }
  return {};
}

String getContinuationString(dynamic ctoken) {
  return "&ctoken=$ctoken&continuation=$ctoken";
}
