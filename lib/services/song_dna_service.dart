import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Real port of Android `SunoLyrics` / Genius + Wikipedia "Song DNA": fetches
/// song background info (meaning, release, writer) from public endpoints.
class SongDnaService {
  SongDnaService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const geniusSearch = 'https://api.genius.com/search';
  static String wikipediaSummary(String lang, String title) =>
      'https://$lang.wikipedia.org/api/rest_v1/page/summary/'
      '${Uri.encodeComponent(title)}';

  /// Pure helper: extract the first hit's full title from a Genius response.
  static String? geniusFirstHit(Map<String, dynamic> json) {
    final response = json['response'];
    if (response is! Map) return null;
    final hits = response['hits'];
    if (hits is! List || hits.isEmpty) return null;
    final first = hits.first;
    if (first is! Map) return null;
    final result = first['result'];
    if (result is! Map) return null;
    return result['full_title']?.toString();
  }

  /// Pure helper: extract the plain-language extract from a Wikipedia summary.
  static String? wikipediaExtract(Map<String, dynamic> json) =>
      json['extract']?.toString();

  Future<String?> fetchGeniusTitle({required String token, required String query}) async {
    if (token.isEmpty) return null;
    try {
      final r = await _client
          .get(
            Uri.parse('$geniusSearch?q=${Uri.encodeComponent(query)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return geniusFirstHit(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[songdna] genius failed: $e');
      return null;
    }
  }

  Future<String?> fetchWikipedia({
    required String lang,
    required String title,
  }) async {
    try {
      final r = await _client
          .get(Uri.parse(wikipediaSummary(lang, title)))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return wikipediaExtract(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[songdna] wikipedia failed: $e');
      return null;
    }
  }
}
