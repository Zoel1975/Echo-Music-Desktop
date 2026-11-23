import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/challenges/js_challenge.dart';

import 'cookie_store.dart';
import 'google_login_service.dart';
import 'po_token_minter.dart';
import 'youtube_explode_client.dart';
import 'youtube_explode_solver.dart';

/// Resolved, playable audio stream, with the identity (headers) its media
/// fetch must wear. Port of Android `playback/ResolvedStream.kt`.
class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.mimeType,
    required this.contentLength,
    required this.bitrate,
    required this.client,
    this.headers = const {},
    this.loudnessDb,
  });

  final String url;
  final String mimeType;
  final int contentLength;
  final int bitrate;
  final String client;
  final Map<String, String> headers;

  /// Track loudness from InnerTube (`loudnessDb` / `trackAbsoluteLoudnessLkfs`),
  /// used by desktop normalization to compute a replay-gain volume.
  final double? loudnessDb;

  /// Linear replay-gain for a target integrated loudness (LUFS), clamped to a
  /// safe range so normalization never distorts or inaudibly quietens a track.
  double normalizationGain({double targetLufs = -14.0}) {
    if (loudnessDb == null) return 1.0;
    final db = (targetLufs - loudnessDb!).clamp(-6.0, 6.0);
    return _dbToGain(db);
  }

  static double _dbToGain(double db) {
    final g = math.pow(10, db / 20).toDouble();
    return g.clamp(0.25, 4.0);
  }

  bool get isM4a =>
      mimeType.contains('audio/mp4') || mimeType.contains('audio/m4a');
}

class StreamResolutionException implements Exception {
  const StreamResolutionException(this.message);
  final String message;
  @override
  String toString() => 'StreamResolutionException: $message';
}

/// InnerTube client catalog (the clients Android's `YouTubeClient.kt` uses to
/// resolve streams). VISIONOS is first: it is the only client we measured that
/// serves the whole file; `ANDROID_VR` (used by the old desktop code) serves a
/// ~1 MiB preview and answers 403 past it.
class YtPlayerClient {
  const YtPlayerClient({
    required this.name,
    required this.version,
    required this.id,
    required this.userAgent,
    this.extra = const <String, dynamic>{},
  });

  final String name;
  final String version;
  final String id;
  final String userAgent;
  final Map<String, dynamic> extra;

  static const visionOs = YtPlayerClient(
    name: 'VISIONOS',
    version: '0.1',
    id: '101',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    extra: {
      'osName': 'visionOS',
      'osVersion': '1.3.21O771',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice14,1',
    },
  );

  static const androidVr165 = YtPlayerClient(
    name: 'ANDROID_VR',
    version: '1.65.10',
    id: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    extra: {
      'osName': 'Android',
      'osVersion': '12L',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': '32',
    },
  );

  static const tvHtml5 = YtPlayerClient(
    name: 'TVHTML5',
    version: '7.20260213.00.00',
    id: '7',
    userAgent:
        'Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 (KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15',
  );

  /// Used by yt-dlp for age-gated videos: with a signature timestamp it can
  /// serve tracks the regular ANDROID client refuses.
  static const androidTestsuite = YtPlayerClient(
    name: 'ANDROID_TESTSUITE',
    version: '19.09.37',
    id: '30',
    userAgent:
        'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip',
    extra: {
      'osName': 'Android',
      'osVersion': '11',
      'androidSdkVersion': '30',
      'deviceMake': 'Google',
      'deviceModel': 'Pixel 4',
    },
  );

  static const webRemix = YtPlayerClient(
    name: 'WEB_REMIX',
    version: '1.20260707.12.00',
    id: '67',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
  );

  /// WEB_REMIX with the embedded-player context: age-gated Music tracks are
  /// often only playable when the request carries `clientScreen=EMBED` and a
  /// thirdParty embedUrl, exactly like the (YouTube) Music web player does.
  static const webRemixEmbedded = YtPlayerClient(
    name: 'WEB_REMIX',
    version: '1.20260707.12.00',
    id: '67',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
    extra: {
      'clientScreen': 'EMBED',
      'thirdParty': {'embedUrl': 'https://music.youtube.com/'},
    },
  );

  /// The embedded player used by the Music web app. With the signed-in
  /// context it is the client that answers age-gated tracks instead of
  /// "Sign in to confirm your age".
  static const webEmbedded = YtPlayerClient(
    name: 'WEB_EMBEDDED_PLAYER',
    version: '2.20260708.00.00',
    id: '56',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    extra: {
      'clientScreen': 'EMBED',
      'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
    },
  );

  /// yt-dlp uses WEB_CREATOR for age-restricted videos when the account needs
  /// age verification. It requires sign-in cookies and a per-video PoToken.
  static const webCreator = YtPlayerClient(
    name: 'WEB_CREATOR',
    version: '1.20260708.06.00',
    id: '62',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
  );

  /// Plain ANDROID still answers `status=OK` without a login when other
  /// clients are bot-blocked. Kept as a last resort; with a visitor token it
  /// can serve a full file, otherwise the deep-probe validation rejects it.
  static const android = YtPlayerClient(
    name: 'ANDROID',
    version: '20.10.38',
    id: '3',
    userAgent: 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    extra: {
      'osName': 'Android',
      'osVersion': '14',
      'androidSdkVersion': '34',
      'deviceMake': 'Google',
      'deviceModel': 'Pixel 9',
    },
  );

  /// Ordered by measured ability to serve a complete audio file.
  static const fallbackOrder = [
    visionOs,
    webRemixEmbedded,
    webCreator,
    androidTestsuite,
    webEmbedded,
    android,
    androidVr165,
    tvHtml5,
    webRemix,
  ];
}

/// Resolves YouTube audio streams through InnerTube `/player`, mirroring the
/// Android app's client fallback chain. Caches successful results.
class StreamResolver {
  StreamResolver._();

  static final StreamResolver instance = StreamResolver._();

  static const _key = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  // Mobile (InnerTubeX v0.7.0) sends no key and no alt=json on /player,
  // only ?prettyPrint=false. The old key caused HTTP 401 with the new client
  // versions used for age-gated playback.
  static const _playerQuery = '?prettyPrint=false';
  static const _playerUrl = 'https://www.youtube.com/youtubei/v1/player$_playerQuery';
  /// YouTube Music's own player endpoint: age-gated Music tracks are only
  /// unlocked by the signed-in WEB_REMIX context Android uses here.
  static const _musicPlayerUrl =
      'https://music.youtube.com/youtubei/v1/player$_playerQuery';
  /// Mobile uses studio.youtube.com for WEB_CREATOR, with a studio-bound
  /// SAPISIDHASH. The old desktop code sent it to www.youtube.com.
  static const _studioPlayerUrl =
      'https://studio.youtube.com/youtubei/v1/player$_playerQuery';

  final http.Client _client = http.Client();

  /// Set at startup by `main()` to the Hive-backed cookie store. Kept as a
  /// callback so this resolver stays independent of Flutter/Hive.
  String? Function()? cookieHeaderProvider;
  final Map<String, ({ResolvedStream stream, DateTime expiry})> _cache = {};

  /// A public `visitorData` token, fetched from a normal YouTube page (no
  /// login/cookies needed). YouTube's bot check rejects `/player` calls whose
  /// client context lacks it — with it, VISIONOS serves the full audio file.
  String? _visitorData;
  DateTime? _visitorDataFetched;

  /// Real `signatureTimestamp` (STS) scraped from the watch page. Mobile
  /// (InnerTubeX `YtConfigParserImpl`) refuses to guess this; a fabricated
  /// days-since-epoch value makes YouTube reject the deciphered format URL.
  String? _signatureTimestamp;
  DateTime? _signatureTimestampFetched;

  /// Loudness metadata of the last resolved stream per video, used by the
  /// desktop normalization engine to compute replay gain.
  final Map<String, double?> _loudness = {};

  double? loudnessFor(String videoId) => _loudness[videoId];

  /// Per-video Proof-of-Origin tokens captured from the signed-in browser.
  /// Web PoTokens are bound to the video id and expire in hours.
  final Map<String, ({String player, String? gvs, DateTime expiry})> _poTokens =
      {};

  String? poTokenFor(String videoId, {bool gvs = false}) {
    final cached = _poTokens[videoId];
    if (cached == null) return null;
    if (DateTime.now().isAfter(cached.expiry)) {
      _poTokens.remove(videoId);
      return null;
    }
    return gvs ? cached.gvs : cached.player;
  }

  void savePoToken(
    String videoId, {
    String? player,
    String? gvs,
    Duration ttl = const Duration(hours: 12),
  }) {
    final old = _poTokens[videoId];
    _poTokens[videoId] = (
      player: player ?? old?.player ?? '',
      gvs: gvs ?? old?.gvs,
      expiry: DateTime.now().add(ttl),
    );
    if (Hive.isBoxOpen('POTOKENS')) {
      Hive.box('POTOKENS').put(videoId, {
        'player': player ?? old?.player ?? '',
        'gvs': gvs ?? old?.gvs,
        'expiry': DateTime.now().add(ttl).toIso8601String(),
      });
    }
  }

  /// Loads persisted PoTokens once; the browser capture writes them later.
  void loadPoTokens() {
    if (!Hive.isBoxOpen('POTOKENS')) return;
    for (final entry in Hive.box('POTOKENS').toMap().entries) {
      if (entry.value is! Map) continue;
      final map = Map<String, dynamic>.from(entry.value as Map);
      final expiry = DateTime.tryParse(map['expiry']?.toString() ?? '');
      if (expiry == null || DateTime.now().isAfter(expiry)) continue;
      _poTokens[entry.key.toString()] = (
        player: map['player']?.toString() ?? '',
        gvs: map['gvs']?.toString(),
        expiry: expiry,
      );
    }
  }

  /// Public visitor token for the youtube_explode fallback client.
  String? get visitorData => _visitorData;

  void clearCache() {
    _cache.clear();
    _loudness.clear();
  }

  /// Pure helper: pull the `VISITOR_DATA` token out of a YouTube page body.
  /// It is escaped JSON, so decode it first to avoid `\\uXXXX` sequences.
  static String? extractVisitorData(String pageHtml) {
    final match = RegExp(r'"VISITOR_DATA":"([^"]+)"').firstMatch(pageHtml);
    if (match == null) return null;
    try {
      final decoded = jsonDecode('"${match.group(1)}"') as String;
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      return match.group(1);
    }
  }

  /// Fetch (and cache for 6 h) a visitor token from a public YouTube page.
  /// Returns null on failure so callers can degrade to the old behaviour.
  Future<String?> _getVisitorData() async {
    final now = DateTime.now();
    if (_visitorData != null &&
        _visitorDataFetched != null &&
        now.difference(_visitorDataFetched!).inHours < 6) {
      return _visitorData;
    }
    try {
      final page = await _client
          .get(
            Uri.parse('https://www.youtube.com/'),
            headers: {'User-Agent': YtPlayerClient.visionOs.userAgent},
          )
          .timeout(const Duration(seconds: 12));
      final token = extractVisitorData(page.body);
      if (token != null && token.isNotEmpty) {
        _visitorData = token;
        _visitorDataFetched = now;
        return token;
      }
    } catch (_) {}
    return null;
  }

  /// Scrapes the 5-digit `signatureTimestamp` from the signed-in watch page,
  /// matching mobile's `YtConfigParserImpl.fetchConfig()`.
  Future<String?> _getSignatureTimestamp(String videoId) async {
    final now = DateTime.now();
    if (_signatureTimestamp != null &&
        _signatureTimestampFetched != null &&
        now.difference(_signatureTimestampFetched!).inHours < 6) {
      return _signatureTimestamp;
    }
    // The signed-out YouTube homepage exposes `"STS":<5 digits>` in ytcfg;
    // mobile's YtConfigParserImpl reads the same value (its watch-page regex
    // is a fallback for surfaces that inline the player config).
    for (final url in [
      'https://www.youtube.com/',
      'https://music.youtube.com/watch?v=$videoId',
    ]) {
      try {
        final page = await _client
            .get(
              Uri.parse(url),
              headers: {'User-Agent': YtPlayerClient.webRemix.userAgent},
            )
            .timeout(const Duration(seconds: 12));
        final match = RegExp(
          r'"STS"?\s*:\s*"?([0-9]{5})|signatureTimestamp"?\s*:\s*([0-9]{5})',
        ).firstMatch(page.body);
        final sts = match?.group(1) ?? match?.group(2);
        if (sts != null) {
          _signatureTimestamp = sts;
          _signatureTimestampFetched = now;
          debugPrint('[resolver] STS=$sts from $url');
          return sts;
        }
      } catch (e) {
        debugPrint('[resolver] STS scrape failed for $url: $e');
      }
    }
    return null;
  }

  /// Selects the best audio format. Prefers m4a/mp4 (media_kit on Windows),
  /// then highest bitrate. Pure helper, unit-testable.
  static List<Map<String, dynamic>> audioFormats(Map<String, dynamic> response) {
    final streaming = response['streamingData'];
    if (streaming is! Map) return const [];
    // Some age-gated / purchased tracks only expose a muxed audio stream in
    // `formats`, not in `adaptiveFormats`. Consider both.
    final raw = <dynamic>[
      ...(streaming['adaptiveFormats'] is List
          ? streaming['adaptiveFormats'] as List
          : const []),
      ...(streaming['formats'] is List ? streaming['formats'] as List : const []),
    ];
    final seen = <dynamic>{};
    return raw
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .where((f) => (f['mimeType'] as String? ?? '').startsWith('audio/'))
        .where((f) => seen.add(f['itag'] ?? f['url']))
        .toList();
  }

  static num _asNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  static ResolvedStream? pick(
    List<Map<String, dynamic>> formats,
    String quality,
    String client,
  ) {
    final usable = formats.where((f) => f['url'] is String).toList();
    if (usable.isEmpty) return null;
    final mp4 = usable.where((f) {
      final m = f['mimeType'] as String? ?? '';
      return m.contains('audio/mp4') || m.contains('audio/m4a');
    }).toList();
    final pool = mp4.isNotEmpty ? mp4 : usable;
    pool.sort((a, b) => _asNum(a['bitrate']).compareTo(_asNum(b['bitrate'])));
    final chosen = quality == 'low' ? pool.first : pool.last;
    // Prefer the absolute-loudness field (LUFS) and fall back to loudnessDb.
    final loudness = chosen['trackAbsoluteLoudnessLkfs'] ?? chosen['loudnessDb'];
    return ResolvedStream(
      url: chosen['url'] as String,
      mimeType: chosen['mimeType'] as String? ?? 'audio/mp4',
      contentLength: _asNum(chosen['contentLength']).toInt(),
      bitrate: _asNum(chosen['bitrate']).toInt(),
      client: client,
      loudnessDb: loudness == null ? null : _asNum(loudness).toDouble(),
    );
  }

  /// GVS (googlevideo) PoTokens travel as the `pot` query parameter. YouTube
  /// binds them to the video id, so they are captured per track.
  static ResolvedStream withGvsPot(ResolvedStream stream, String? pot) {
    if (pot == null || pot.isEmpty) return stream;
    final uri = Uri.tryParse(stream.url);
    if (uri == null) return stream;
    final params = Map<String, String>.from(uri.queryParameters)..['pot'] = pot;
    // Mobile adds a fresh 16-char client playback nonce per extraction.
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final random = math.Random();
    params['cpn'] = List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return ResolvedStream(
      url: uri.replace(queryParameters: params).toString(),
      mimeType: stream.mimeType,
      contentLength: stream.contentLength,
      bitrate: stream.bitrate,
      client: stream.client,
      headers: stream.headers,
      loudnessDb: stream.loudnessDb,
    );
  }

  bool _statusOk(Map<String, dynamic> response) =>
      response['playabilityStatus']?['status'] == 'OK';

  /// Account-bound visitor id, saved by the YouTube Music login flow.
  static String? get _signedInVisitor {
    try {
      if (!Hive.isBoxOpen('SETTINGS')) return null;
      return Hive.box('SETTINGS').get('VISITOR_ID')?.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers(YtPlayerClient client, {bool music = false}) {
    final studio = client.name == 'WEB_CREATOR';
    final origin = studio
        ? 'https://studio.youtube.com'
        : music
            ? 'https://music.youtube.com'
            : 'https://www.youtube.com';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-Youtube-Client-Name': client.id,
      'X-Youtube-Client-Version': client.version,
      'X-Goog-Api-Format-Version': '1',
      'X-Origin': origin,
      'Origin': origin,
      'Accept-Language': 'en-US,en;q=0.8',
      'Referer': '$origin/',
    };
    final cookie = cookieHeaderProvider?.call();
    if (cookie != null) headers['Cookie'] = cookie;
    // Mobile sends the visitor id on EVERY client, incl. VISIONOS/ANDROID.
    final visitor = music ? _signedInVisitor : (_visitorData ?? _signedInVisitor);
    if (visitor != null && visitor.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitor;
    }
    // Only web-style clients accept a SAPISIDHASH on /player.
    final webClient = client.name == 'WEB_REMIX' ||
        client.name == 'WEB_EMBEDDED_PLAYER' ||
        studio;
    if (webClient) {
      final auth = CookieStore.instance.authorizationHeaderFor(origin);
      if (auth != null) {
        headers['Authorization'] = auth;
        headers['X-Goog-AuthUser'] = '0';
      }
    }
    return headers;
  }

  /// Testable wrappers for the request builders.
  Map<String, String> buildHeaders(YtPlayerClient client, {bool music = false}) =>
      _headers(client, music: music);

  Map<String, dynamic> buildBody(
    YtPlayerClient client,
    String videoId, {
    String? visitorData,
    String? signatureTimestamp,
  }) =>
      _body(client, videoId,
          visitorData: visitorData, signatureTimestamp: signatureTimestamp);

  Map<String, dynamic> _body(
    YtPlayerClient client,
    String videoId, {
    String? visitorData,
    String? signatureTimestamp,
  }) {
    final signedVisitor = _signedInVisitor;
    final dataSyncId = CookieStore.instance.dataSyncId;
    final web = client.name == 'WEB_REMIX' || client.name == 'WEB_CREATOR';
    return {
      'context': {
        'client': <String, dynamic>{
          'clientName': client.name,
          'clientVersion': client.version,
          'hl': 'en',
          'gl': 'US',
          ...client.extra,
          if (visitorData != null && visitorData.isNotEmpty)
            'visitorData': visitorData
          else if (signedVisitor != null && signedVisitor.isNotEmpty)
            'visitorData': signedVisitor,
        },
        // Mobile (InnerTubeX) always serializes these. `onBehalfOfUser` used
        // to 401 when sent to /player with our account id, so keep it out by
        // default and only add it for the signed-in web clients that need it.
        'request': {
          'internalExperimentFlags': [],
          'useSsl': true,
        },
        if (web && dataSyncId != null && dataSyncId.isNotEmpty)
          'user': {
            'lockedSafetyMode': false,
            'onBehalfOfUser': dataSyncId,
          },
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
      if (web) 'videoCheckOk': true,
      if ((poTokenFor(videoId) ?? '').isNotEmpty)
        'serviceIntegrityDimensions': {'poToken': poTokenFor(videoId)},
      'playbackContext': {
        'contentPlaybackContext': {
          if (web) 'html5Preference': 'HTML5_PREF_WANTS',
          'signatureTimestamp': signatureTimestamp ??
              (DateTime.now()
                      .difference(DateTime.fromMillisecondsSinceEpoch(0))
                      .inDays -
                  1),
        },
      },
    };
  }

  /// Probes the stream URL the same way ExoPlayer/media_kit does: a ranged
  /// GET. A Range-less probe answers 403 on every YouTube Music art track.
  Future<bool> _validate(ResolvedStream stream) async {
    // Probe both the head and a deep offset. Clients like plain ANDROID serve
    // only the first ~1 MiB (403 past it); a byte-0 probe would wrongly accept
    // that throttled stream and playback would die a minute in.
    final probes = <int>[0];
    if (stream.contentLength > 1500000) {
      probes.add(stream.contentLength ~/ 2);
    }
    for (final start in probes) {
      try {
        final r = await _client
            .get(
              Uri.parse(stream.url),
              headers: {
                ...stream.headers,
                'Range': 'bytes=$start-${start + 1023}',
                'User-Agent': stream.headers['User-Agent'] ??
                    YtPlayerClient.visionOs.userAgent,
              },
            )
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200 && r.statusCode != 206) {
          debugPrint(
            '[validate] reject range=$start status=${r.statusCode} '
            'len=${r.bodyBytes.length} body=${String.fromCharCodes(r.bodyBytes.take(80))}',
          );
          return false;
        }
      } catch (e) {
        debugPrint('[validate] range=$start exception=$e');
        return false;
      }
    }
    return true;
  }

  /// Diagnostic: signed-in Music watch page for player-JS extraction checks.
  Future<String> debugWatchPage(String videoId) async {
    final page = await _client.get(
      Uri.parse('https://music.youtube.com/watch?v=$videoId'),
      headers: _headers(YtPlayerClient.webRemix, music: true),
    );
    return page.body;
  }

  /// Diagnostic: raw WEB_REMIX player response for age-gated investigations.
  Future<Map<String, dynamic>> debugPlayer(String videoId) async {
    final client = YtPlayerClient.webRemix;
    final response = await _client.post(
      Uri.parse(_musicPlayerUrl),
      headers: _headers(client, music: true),
      body: jsonEncode(_body(
        client,
        videoId,
        visitorData: _signedInVisitor ?? await _getVisitorData(),
        signatureTimestamp: await _getSignatureTimestamp(videoId),
      )),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Decipher the `signatureCipher` fields returned by WEB_REMIX for
  /// age-restricted tracks, using the same JS challenge solver as
  /// youtube_explode_dart but with our signed-in Music context.
  Future<ResolvedStream?> _resolveWithCipher(String videoId) async {
    if (!NodeEJSSolver.isNodeAvailable) return null;
    try {
      final raw = await debugPlayer(videoId);
      final formats = (raw['streamingData']?['adaptiveFormats'] as List? ??
              const [])
          .whereType<Map>()
          .where((f) =>
              (f['mimeType'] as String? ?? '').startsWith('audio/') &&
              f['signatureCipher'] is String)
          .toList()
        ..sort((a, b) => _asNum(b['bitrate']).compareTo(_asNum(a['bitrate'])));
      if (formats.isEmpty) return null;

      final page = await _client.get(
        Uri.parse('https://music.youtube.com/watch?v=$videoId'),
        headers: _headers(YtPlayerClient.webRemix, music: true),
      );
      String? playerJs;
      final jsMatch = RegExp(r'"PLAYER_JS_URL":"([^"]+)"').firstMatch(page.body);
      if (jsMatch != null) {
        playerJs = jsonDecode('"${jsMatch.group(1)}"') as String;
      }
      // YouTube Music embeds the player path as "jsUrl" in its ytcfg.
      final jsUrlMatch = RegExp(r'"jsUrl":"([^"]+)"').firstMatch(page.body);
      if (jsUrlMatch != null) {
        playerJs = jsonDecode('"${jsUrlMatch.group(1)}"') as String;
      }
      playerJs ??= RegExp(r'/s/player/[A-Za-z0-9_./*\-]+\.js')
          .firstMatch(page.body)
          ?.group(0);
      if (playerJs != null && playerJs.startsWith('/')) {
        playerJs = 'https://www.youtube.com$playerJs';
      }
      if (playerJs == null) {
        debugPrint('[cipher] no player js in watch page (${page.body.length} bytes)');
        return null;
      }
      final solver = await NodeEJSSolver.create();
      for (final format in formats.take(3)) {
        final params = Uri.splitQueryString(format['signatureCipher'] as String);
        final base = Uri.parse(params['url'] ?? '');
        final sig = params['s'];
        final sigKey = params['sp'] ?? 'sig';
        final n = base.queryParameters['n'];
        if (base.toString().isEmpty || sig == null || sig.isEmpty) continue;
        final solved = await solver.solveBulk(
          playerJs,
          {
            JSChallengeType.sig: [sig],
            if (n != null && n.isNotEmpty) JSChallengeType.n: [n],
          },
        );
        final newSig = solved[sig];
        if (newSig == null || newSig.isEmpty) continue;
        final query = Map<String, String>.from(base.queryParameters);
        query[sigKey] = newSig;
        final newN = n == null ? null : solved[n];
        if (n != null && newN != null) query['n'] = newN;
        final stream = withGvsPot(
          ResolvedStream(
            url: base.replace(queryParameters: query).toString(),
            mimeType: format['mimeType'] as String? ?? 'audio/mp4',
            contentLength: _asNum(format['contentLength']).toInt(),
            bitrate: _asNum(format['bitrate']).toInt(),
            client: 'CIPHER',
            headers: {
              'User-Agent': YtPlayerClient.webRemix.userAgent,
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
          ),
          poTokenFor(videoId, gvs: true),
        );
        if (await _validate(stream)) return stream;
        debugPrint('[cipher] format ${format['itag']} rejected');
      }
    } catch (e) {
      debugPrint('[cipher] $videoId: $e');
    }
    return null;
  }

  /// Diagnostic entry point for the signatureCipher path (same one mobile's
  /// InnerTubeX extractor uses for age-gated tracks).
  Future<ResolvedStream?> debugCipher(String videoId) =>
      _resolveWithCipher(videoId);

  /// Diagnostic: decipher one format, then probe the URL with the identity
  /// variants mobile uses, to isolate which one YouTube accepts.
  Future<Map<String, dynamic>> debugCipherDiag(String videoId) async {
    final out = <String, dynamic>{};
    try {
      out['sts'] = await _getSignatureTimestamp(videoId);
      final raw = await debugPlayer(videoId);
      final formats = (raw['streamingData']?['adaptiveFormats'] as List? ?? [])
          .whereType<Map>()
          .where((f) =>
              (f['mimeType'] as String? ?? '').startsWith('audio/') &&
              f['signatureCipher'] is String)
          .toList();
      out['cipherFormats'] = formats.length;
      if (formats.isEmpty) return out;
      final page = await _client.get(
        Uri.parse('https://music.youtube.com/watch?v=$videoId'),
        headers: _headers(YtPlayerClient.webRemix, music: true),
      );
      String? playerJs;
      final jsUrlMatch = RegExp(r'"jsUrl":"([^"]+)"').firstMatch(page.body);
      if (jsUrlMatch != null) {
        playerJs = jsonDecode('"${jsUrlMatch.group(1)}"') as String;
      }
      if (playerJs != null && playerJs.startsWith('/')) {
        playerJs = 'https://www.youtube.com$playerJs';
      }
      out['playerJs'] = playerJs;
      out['stsMatches'] = RegExp(
        r'.{0,40}(?:signatureTimestamp|"sts"|"STS"|sts).{0,60}',
        caseSensitive: false,
      ).allMatches(page.body).take(8).map((m) => m.group(0)).toList();
      if (playerJs == null) return out;
      final solver = await NodeEJSSolver.create();
      final format = formats.first;
      final params = Uri.splitQueryString(format['signatureCipher'] as String);
      final base = Uri.parse(params['url'] ?? '');
      final sig = params['s'];
      final n = base.queryParameters['n'];
      if (sig == null || base.toString().isEmpty) return out;
      final solved = await solver.solveBulk(
        playerJs,
        {
          JSChallengeType.sig: [sig],
          if (n != null && n.isNotEmpty) JSChallengeType.n: [n],
        },
      );
      final newSig = solved[sig];
      final query = Map<String, String>.from(base.queryParameters)
        ..[params['sp'] ?? 'sig'] = newSig ?? '';
      if (n != null && solved[n] != null) query['n'] = solved[n]!;
      final plain = base.replace(queryParameters: query).toString();
      final minted = poTokenFor(videoId, gvs: true) ?? '';
      out['mintedPotLength'] = minted.length;
      final potUrl = Uri.parse(plain);
      final potParams = Map<String, String>.from(potUrl.queryParameters)
        ..['pot'] = minted
        ..['cpn'] = 'abcdefghijklmnop';

      Future<void> test(String name, String url, Map<String, String> h) async {
        try {
          final r = await _client
              .get(Uri.parse(url),
                  headers: {...h, 'Range': 'bytes=0-1023'})
              .timeout(const Duration(seconds: 12));
          out[name] = 'status=${r.statusCode} len=${r.bodyBytes.length}';
        } catch (e) {
          out[name] = 'error=$e';
        }
      }

      final ff = {'User-Agent': YtPlayerClient.webRemix.userAgent};
      final vis = {'User-Agent': YtPlayerClient.visionOs.userAgent};
      await test('plain_ff', plain, ff);
      await test('plain_vis', plain, vis);
      await test('pot_ff', potUrl.toString(), ff);
      await test('pot_vis', potUrl.toString(), vis);
      await test('pot_cookie', potUrl.toString(), {
        ...ff,
        if (cookieHeaderProvider?.call() != null)
          'Cookie': cookieHeaderProvider!.call()!,
      });
      out['urlHead'] = plain.length > 160 ? plain.substring(0, 160) : plain;
    } catch (e) {
      out['error'] = e.toString();
    }
    return out;
  }

  /// Last-resort resolver for age-restricted videos: youtube_explode_dart
  /// handles `signatureCipher` / `n` challenges that InnerTube leaves as
  /// "no direct audio format". Uses the signed-in cookie jar and a Node-backed
  /// JS solver when available.
  Future<ResolvedStream?> _resolveWithExplode(
    String videoId,
    String quality,
  ) async {
    if (!NodeEJSSolver.isNodeAvailable) return null;
    YoutubeExplode? yt;
    try {
      final solver = await NodeEJSSolver.create();
      yt = YoutubeExplode(
        httpClient: AuthYoutubeHttpClient(),
        jsSolver: solver,
      );
      // Try clients separately: getManifest merges their streams and can pick
      // a deciphered URL that mpv cannot actually read.
      for (final apiClient in [
        YoutubeApiClient.tvSimplyEmbedded,
        YoutubeApiClient.webCreator,
        YoutubeApiClient.mweb,
        YoutubeApiClient.tv,
        YoutubeApiClient.androidSdkless,
        YoutubeApiClient.androidVr,
        YoutubeApiClient.safari,
      ]) {
        try {
          final manifest = await yt.videos.streamsClient.getManifest(
            videoId,
            requireWatchPage: false,
            ytClients: [apiClient],
          );
          final infos = manifest.audioOnly.toList()
            ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
          if (infos.isEmpty) continue;
          final chosen = quality == 'low' ? infos.first : infos.last;
          final stream = ResolvedStream(
            url: chosen.url.toString(),
            mimeType: chosen.codec.mimeType,
            contentLength: chosen.size.totalBytes.toInt(),
            bitrate: chosen.bitrate.bitsPerSecond.toInt(),
            client: 'EXPLODE',
            headers: {'User-Agent': YtPlayerClient.visionOs.userAgent},
          );
          if (!await _validate(stream)) {
            debugPrint('[explode] tag ${chosen.tag} rejected by ranged GET');
            continue;
          }
          return stream;
        } catch (e) {
          debugPrint('[explode] client failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[explode] $videoId: $e');
      return null;
    } finally {
      yt?.close();
    }
  }

  Future<ResolvedStream> resolve(
    String videoId, {
    String quality = 'high',
    bool allowPoTokenCapture = true,
  }) async {
    final key = '$videoId:$quality';
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      return cached.stream;
    }

    // A public visitor token clears the "confirm you're not a bot" check
    // without requiring a Google sign-in. Fetch once per resolve; it is cached.
    final visitorData = await _getVisitorData();
    final sts = await _getSignatureTimestamp(videoId);

    final errors = <String>[];
    // Transient 429/5xx/timeouts are common on mobile networks: retry the
    // whole client chain once before giving up, so a single hiccup does not
    // look like "the play button did nothing".
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      final roundErrors = <String>[];
      for (final client in YtPlayerClient.fallbackOrder) {
        try {
          final music = client.name == 'WEB_REMIX';
          final endpoint = client.name == 'WEB_CREATOR'
              ? _studioPlayerUrl
              : music
                  ? _musicPlayerUrl
                  : _playerUrl;
          final response = await _client
              .post(
                Uri.parse(endpoint),
                headers: _headers(client, music: music),
                body: jsonEncode(_body(
                  client,
                  videoId,
                  visitorData: music ? _signedInVisitor : visitorData,
                  signatureTimestamp: sts,
                )),
              )
              .timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            roundErrors.add('${client.name}: HTTP ${response.statusCode}');
            continue;
          }
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (!_statusOk(data)) {
            roundErrors
                .add('${client.name}: ${data['playabilityStatus']?['reason']}');
            continue;
          }
          final picked = pick(audioFormats(data), quality, client.name);
          if (picked == null) {
            roundErrors.add('${client.name}: no direct audio format');
            // Age-gated player responses return only `signatureCipher` formats.
            // Mobile's InnerTubeX deciphers them here rather than falling back
            // to a browser capture whose URL YouTube rejects.
            final deciphered = await _resolveWithCipher(videoId);
            if (deciphered != null) {
              _loudness[videoId] = deciphered.loudnessDb;
              _cache[key] = (
                stream: deciphered,
                expiry: DateTime.now().add(const Duration(hours: 1)),
              );
              return deciphered;
            }
            continue;
          }
          final stream = withGvsPot(
            picked,
            poTokenFor(videoId, gvs: true),
          );
          if (!await _validate(stream)) {
            roundErrors.add('${client.name}: stream URL rejected (403/429)');
            continue;
          }

          final expires =
              _asNum(data['streamingData']?['expiresInSeconds']) == 0
                  ? 3600
                  : _asNum(data['streamingData']?['expiresInSeconds']).toInt();
          final ttl = Duration(seconds: expires.clamp(300, 3600));
          _loudness[videoId] = stream.loudnessDb;
          _cache[key] = (stream: stream, expiry: DateTime.now().add(ttl));
          return stream;
        } catch (e) {
          roundErrors.add('${client.name}: $e');
        }
      }
      errors
        ..clear()
        ..addAll(roundErrors);
    }
    // Age gate: YouTube ties the playable URL to a PoToken generated in the
    // signed-in browser. Open the video there, let the user confirm their age,
    // then reuse the stream Chrome obtained.
    final ageGated = errors.any((e) {
      final lower = e.toLowerCase();
      return lower.contains('age') ||
          lower.contains('inappropriate') ||
          lower.contains('unavailable') ||
          lower.contains('sign in');
    });
    if (ageGated && allowPoTokenCapture) {
      // Mobile's fix: mint a BotGuard PoToken locally in a hidden browser page
      // (no login, no user interaction) and retry with it. The token is bound
      // to the session visitor id and reused for the session.
      // Bind the token to the exact visitor id we send in X-Goog-Visitor-Id.
      final visitor = _headers(YtPlayerClient.webRemix, music: true)[
          'X-Goog-Visitor-Id'];
      final identifier = CookieStore.instance.dataSyncId?.isNotEmpty == true
          ? CookieStore.instance.dataSyncId!
          : (visitor ?? _visitorData ?? _signedInVisitor ?? 'visitor');
      final token = await PoTokenMinter.instance.mint(identifier);
      if (token != null && token.isNotEmpty) {
        savePoToken(videoId, player: token, gvs: token);
        _cache.remove(key);
        try {
          return await resolve(
            videoId,
            quality: quality,
            allowPoTokenCapture: false,
          );
        } on StreamResolutionException catch (retryError) {
          debugPrint('[resolver] retry con PoToken fallito: ${retryError.message}');
          // Fall through to the legacy browser capture below.
        }
      }
      // Last resort: the old interactive capture of Chrome's own stream URL.
      final captured = await GoogleLoginService().capturePoToken(videoId);
      final streamUrl = captured?.streamUrl;
      if (streamUrl != null) {
        final stream = ResolvedStream(
          url: streamUrl,
          mimeType: 'audio/mpeg',
          contentLength: 0,
          bitrate: 0,
          client: 'BROWSER',
          headers: captured?.headers ?? const {},
        );
        if (await _validate(stream)) {
          _cache[key] = (
            stream: stream,
            expiry: DateTime.now().add(const Duration(minutes: 30)),
          );
          return stream;
        }
      }
    }
    final deciphered = await _resolveWithCipher(videoId);
    final exploded = deciphered ?? await _resolveWithExplode(videoId, quality);
    if (exploded != null) {
      _loudness[videoId] = exploded.loudnessDb;
      _cache[key] = (
        stream: exploded,
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );
      return exploded;
    }
    throw StreamResolutionException(
      'No playable audio stream for $videoId. ${errors.join(' | ')}',
    );
  }
}
