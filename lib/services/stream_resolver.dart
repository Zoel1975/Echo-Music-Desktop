import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

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
    this.extra = const {},
  });

  final String name;
  final String version;
  final String id;
  final String userAgent;
  final Map<String, String> extra;

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

  static const webRemix = YtPlayerClient(
    name: 'WEB_REMIX',
    version: '1.20260213.01.00',
    id: '67',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
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
  static const _playerUrl =
      'https://www.youtube.com/youtubei/v1/player?alt=json&key=$_key';

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

  /// Loudness metadata of the last resolved stream per video, used by the
  /// desktop normalization engine to compute replay gain.
  final Map<String, double?> _loudness = {};

  double? loudnessFor(String videoId) => _loudness[videoId];

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

  /// Selects the best audio format. Prefers m4a/mp4 (media_kit on Windows),
  /// then highest bitrate. Pure helper, unit-testable.
  static List<Map<String, dynamic>> audioFormats(Map<String, dynamic> response) {
    final formats = response['streamingData']?['adaptiveFormats'];
    if (formats is! List) return const [];
    return formats
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .where((f) => (f['mimeType'] as String? ?? '').startsWith('audio/'))
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

  bool _statusOk(Map<String, dynamic> response) =>
      response['playabilityStatus']?['status'] == 'OK';

  Map<String, String> _headers(YtPlayerClient client) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-Youtube-Client-Name': client.id,
      'X-Youtube-Client-Version': client.version,
      'Origin': 'https://www.youtube.com',
    };
    final cookie = cookieHeaderProvider?.call();
    if (cookie != null) headers['Cookie'] = cookie;
    return headers;
  }

  Map<String, dynamic> _body(
    YtPlayerClient client,
    String videoId, {
    String? visitorData,
  }) {
    return {
      'context': {
        'client': <String, dynamic>{
          'clientName': client.name,
          'clientVersion': client.version,
          'hl': 'en',
          'gl': 'US',
          ...client.extra,
          if (visitorData != null) 'visitorData': visitorData,
        },
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
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
                'User-Agent': YtPlayerClient.visionOs.userAgent,
              },
            )
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200 && r.statusCode != 206) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<ResolvedStream> resolve(String videoId, {String quality = 'high'}) async {
    final key = '$videoId:$quality';
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      return cached.stream;
    }

    // A public visitor token clears the "confirm you're not a bot" check
    // without requiring a Google sign-in. Fetch once per resolve; it is cached.
    final visitorData = await _getVisitorData();

    final errors = <String>[];
    for (final client in YtPlayerClient.fallbackOrder) {
      try {
        final response = await _client
            .post(
              Uri.parse(_playerUrl),
              headers: _headers(client),
              body: jsonEncode(_body(client, videoId, visitorData: visitorData)),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          errors.add('${client.name}: HTTP ${response.statusCode}');
          continue;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!_statusOk(data)) {
          errors.add('${client.name}: ${data['playabilityStatus']?['reason']}');
          continue;
        }
        final stream = pick(audioFormats(data), quality, client.name);
        if (stream == null) {
          errors.add('${client.name}: no direct audio format');
          continue;
        }
        if (!await _validate(stream)) {
          errors.add('${client.name}: stream URL rejected (403/429)');
          continue;
        }

        final expires = _asNum(data['streamingData']?['expiresInSeconds']) == 0 ? 3600 : _asNum(data['streamingData']?['expiresInSeconds']).toInt();
        final ttl = Duration(seconds: expires.clamp(300, 3600));
        _loudness[videoId] = stream.loudnessDb;
        _cache[key] = (stream: stream, expiry: DateTime.now().add(ttl));
        return stream;
      } catch (e) {
        errors.add('${client.name}: $e');
      }
    }
    throw StreamResolutionException(
      'No playable audio stream for $videoId. ${errors.join(' | ')}',
    );
  }
}
