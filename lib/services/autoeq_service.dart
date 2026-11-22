import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'axion_eq_service.dart';

/// A profile from the official AutoEq results index, searched in-app.
@immutable
class AutoEqProfile {
  const AutoEqProfile({
    required this.name,
    required this.path,
    required this.source,
  });

  final String name;
  /// URL-encoded path relative to `results/`, straight from INDEX.md.
  final String path;
  final String source;

  String get displayName {
    final target = Uri.decodeComponent(path.split('/').last);
    return target.toLowerCase() == name.toLowerCase() ? name : '$name · $target';
  }
}

/// In-app AutoEq database search: downloads the small INDEX.md once, caches it
/// for 7 days, then fetches just the chosen ParametricEQ.txt.
class AutoEqService {
  AutoEqService._();

  static const _indexUrl =
      'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md';
  static const _rawBase =
      'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/';
  static const _cacheKey = 'autoeqIndex';
  static const _cacheTimeKey = 'autoeqIndexTime';

  static List<AutoEqProfile> _profiles = const [];
  static DateTime? _fetched;

  /// Pure parser for the markdown index (`- [Name](./source/target/path)`).
  static List<AutoEqProfile> parseIndex(String markdown) {
    final out = <AutoEqProfile>[];
    final re = RegExp(r'^- \[([^\]]+)\]\(\./([^)]+)\)', multiLine: true);
    for (final match in re.allMatches(markdown)) {
      final name = match.group(1)?.trim() ?? '';
      final path = match.group(2)?.trim() ?? '';
      if (name.isEmpty || path.isEmpty || path.contains('#')) continue;
      final segments = path.split('/');
      final source = segments.isEmpty ? '' : Uri.decodeComponent(segments.first);
      out.add(AutoEqProfile(name: name, path: path, source: source));
    }
    return out;
  }

  /// Pure: raw URL for a profile's ParametricEQ.txt.
  static String parametricEqUrl(AutoEqProfile profile) {
    final last = Uri.decodeComponent(profile.path.split('/').last);
    final file = Uri.encodeComponent('$last ParametricEQ.txt');
    // Keep the profile directory itself: .../AKG K371/AKG K371 ParametricEQ.txt
    return '$_rawBase${profile.path}/$file';
  }

  /// Pure: ranked search over profile names (prefix > substring > tokens).
  static List<AutoEqProfile> search(
    List<AutoEqProfile> profiles,
    String query, {
    int limit = 40,
  }) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return profiles.take(limit).toList();
    final scored = <(AutoEqProfile profile, int score)>[];
    for (final p in profiles) {
      final name = p.name.toLowerCase();
      var score = 0;
      if (name.startsWith(q)) {
        score = 100 - name.length;
      } else if (name.contains(q)) {
        score = 60 - name.indexOf(q);
      } else {
        final tokens = q.split(RegExp(r'\s+'));
        if (tokens.every(name.contains)) score = 20;
      }
      if (score > 0) scored.add((p, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  static Future<List<AutoEqProfile>> loadProfiles({bool force = false}) async {
    if (!force && _profiles.isNotEmpty) return _profiles;
    try {
      if (Hive.isBoxOpen('SETTINGS')) {
        final box = Hive.box('SETTINGS');
        final cached = box.get(_cacheKey)?.toString() ?? '';
        final time = box.get(_cacheTimeKey) as DateTime?;
        if (!force &&
            cached.isNotEmpty &&
            time != null &&
            DateTime.now().difference(time).inDays < 7) {
          _profiles = parseIndex(cached);
          if (_profiles.isNotEmpty) return _profiles;
        }
      }
      final response =
          await http.get(Uri.parse(_indexUrl)).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        _profiles = parseIndex(response.body);
        _fetched = DateTime.now();
        if (Hive.isBoxOpen('SETTINGS')) {
          final box = Hive.box('SETTINGS');
          await box.put(_cacheKey, response.body);
          await box.put(_cacheTimeKey, _fetched);
        }
      }
    } catch (e) {
      debugPrint('[autoeq] index: $e');
    }
    return _profiles;
  }

  static DateTime? get lastFetched => _fetched;

  /// Fetch and parse the 10-band gains for a selected profile.
  static Future<List<double>?> gainsFor(AutoEqProfile profile) async {
    try {
      final url = parametricEqUrl(profile);
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('[autoeq] ${response.statusCode} $url');
        return null;
      }
      final gains = AxionEqService.parseAutoEqProfile(response.body);
      return gains.any((g) => g != 0) ? gains : null;
    } catch (e) {
      debugPrint('[autoeq] profile: $e');
      return null;
    }
  }
}
