import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A SponsorBlock skip segment [start, end] in seconds.
@immutable
class SponsorSegment {
  const SponsorSegment(
      {required this.start, required this.end, this.category = ''});
  final double start;
  final double end;
  final String category;

  factory SponsorSegment.fromJson(Map<String, dynamic> json) {
    final seg = (json['segment'] as List?) ?? const [];
    return SponsorSegment(
      start: (seg.isNotEmpty ? seg[0] : 0).toDouble(),
      end: (seg.length > 1 ? seg[1] : 0).toDouble(),
      category: json['category']?.toString() ?? '',
    );
  }
}

/// Real port of Android `SponsorBlockRepository`: fetches skip segments from
/// the public SponsorBlock API, caches them, and finds the segment covering a
/// playback position. Used by MediaPlayer to auto-skip sponsored parts.
class SponsorBlockService {
  SponsorBlockService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<SponsorSegment>> _cache = {};

  static const _categories = [
    'sponsor',
    'intro',
    'outro',
    'interaction',
    'selfpromo',
    'music_offtopic',
  ];

  static String _url(String videoId) {
    final cats = jsonEncode(_categories);
    return 'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId'
        '&categories=${Uri.encodeComponent(cats)}';
  }

  /// Pure helper: which segment (if any) contains [seconds].
  static SponsorSegment? segmentAt(
    List<SponsorSegment> segments,
    double seconds,
  ) {
    for (final s in segments) {
      if (seconds >= s.start && seconds < s.end) return s;
    }
    return null;
  }

  Future<List<SponsorSegment>> getSegments(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null) return cached;
    try {
      final response = await _client
          .get(Uri.parse(_url(videoId)))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _cache[videoId] = const [];
        return const [];
      }
      final list = jsonDecode(response.body) as List<dynamic>;
      final segments = list
          .whereType<Map<String, dynamic>>()
          .map(SponsorSegment.fromJson)
          .where((s) => s.end > s.start)
          .toList();
      _cache[videoId] = segments;
      return segments;
    } catch (_) {
      return const [];
    }
  }

  void clearCache() => _cache.clear();
}
