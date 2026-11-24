import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'audio_source_info.dart';

/// Monochrome public API (https://monochrome.st/), no account required.
/// `/search?q=` returns track metadata, `/track/<id>` serves the FLAC bytes
/// directly with `Accept-Ranges: bytes` and permissive CORS. Used as a
/// lossless quality option for Echo playback.
class MonochromeTrack {
  const MonochromeTrack({
    required this.id,
    required this.title,
    this.artist = '',
    this.durationMs = 0,
    this.isrc = '',
  });

  final String id;
  final String title;
  final String artist;
  final int durationMs;
  final String isrc;

  String get streamUrl => '${MonochromeService.base}/track/$id';

  factory MonochromeTrack.fromJson(Map<String, dynamic> json) {
    final artists = json['artistNames'] ?? json['artists'];
    String firstArtist = '';
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      firstArtist = first is Map
          ? (first['name'] ?? '').toString()
          : first?.toString() ?? '';
    }
    return MonochromeTrack(
      id: (json['id'] ?? json['trackId'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      artist: firstArtist,
      durationMs: (json['duration'] is num)
          ? (json['duration'] as num).toInt()
          : int.tryParse(json['duration']?.toString() ?? '') ?? 0,
      isrc: json['isrc']?.toString() ?? '',
    );
  }
}

class MonochromeService {
  MonochromeService._();

  static const defaultBase = 'https://tracks.monochrome.st';
  static String base = defaultBase;

  /// Android's custom extension server URL. Empty restores the public API.
  static void configureBase(String? url) =>
      base = (url == null || url.trim().isEmpty) ? defaultBase : url.trim();
  static final http.Client _client = http.Client();
  static final Map<String, List<MonochromeTrack>> _cache = {};
  static final Map<String, FlacStreamInfo> _flacInfoCache = {};

  /// The CDN rejects requests with a generic library User-Agent (HTTP 429
  /// "oooooooooooooooooof beep boop"). A browser UA + referer is required for
  /// both the audio bytes and the small STREAMINFO probe.
  static const browserHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://monochrome.st/',
    'Accept': 'audio/flac,*/*',
  };

  /// Reads the FLAC STREAMINFO header (42 bytes) so the player can show the
  /// real sample rate / bit depth instead of a generic "FLAC" label. Cached
  /// per track and best-effort: a 429 leaves the plain label in place.
  static Future<FlacStreamInfo?> probeFlacInfo(MonochromeTrack track) async {
    final cached = _flacInfoCache[track.id];
    if (cached != null) return cached;
    try {
      final request = http.Request('GET', Uri.parse(track.streamUrl))
        ..headers.addAll({...browserHeaders, 'Range': 'bytes=0-41'});
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final bytes = await response.stream.toBytes();
      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }
      final info = FlacStreamInfo.parse(bytes);
      if (info != null) _flacInfoCache[track.id] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Pure parser, unit-testable without network.
  static List<MonochromeTrack> parseSearch(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final tracks = decoded['tracks'];
    if (tracks is! List) return const [];
    return tracks
        .whereType<Map>()
        .map((t) => MonochromeTrack.fromJson(Map<String, dynamic>.from(t)))
        .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
        .toList();
  }

  static Future<List<MonochromeTrack>> search(
    String query, {
    int limit = 5,
  }) async {
    final key = '${query.trim().toLowerCase()}|$limit';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (query.trim().isEmpty) return const [];
    try {
      final uri = Uri.parse('$base/search').replace(
        queryParameters: {'q': query.trim()},
      );
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
          'Referer': 'https://monochrome.st/',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      final results = parseSearch(response.body).take(limit).toList();
      if (results.isNotEmpty && _cache.length < 200) _cache[key] = results;
      return results;
    } catch (e) {
      debugPrint('[monochrome] search failed: $e');
      return const [];
    }
  }

  static void clearCache() => _cache.clear();

  /// Best match for a song, preferring an exact ISRC match when available.
  static Future<MonochromeTrack?> findSong({
    required String title,
    String? artist,
    String? isrc,
  }) async {
    if (isrc != null && isrc.isNotEmpty) {
      final byIsrc = await search(isrc, limit: 5);
      for (final t in byIsrc) {
        if (t.isrc.toLowerCase() == isrc.toLowerCase()) return t;
      }
    }
    final query = artist == null || artist.isEmpty
        ? title
        : '$artist $title';
    final results = await search(query, limit: 5);
    if (results.isEmpty) return null;
    final wanted = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final t in results) {
      final candidate = t.title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (candidate.contains(wanted) || wanted.contains(candidate)) return t;
    }
    return results.first;
  }

  /// Convenience: resolve from the song map used throughout the player.
  static Future<MonochromeTrack?> findBySong(Map<String, dynamic> song) async {
    final title = song['title']?.toString() ?? '';
    if (title.isEmpty) return null;
    final artists = song['artists'];
    String? artist;
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map && first['name'] != null) artist = first['name'].toString();
    }
    return findSong(
      title: title,
      artist: artist,
      isrc: song['isrc']?.toString(),
    );
  }
}
