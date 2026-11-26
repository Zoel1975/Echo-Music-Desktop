import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'axion_eq_service.dart';

/// In-app search over the official AutoEq results database.
/// The 850 KB `results/INDEX.md` is fetched once and cached in Hive, so search
/// is instant and works offline afterwards.
class AutoEqProfile {
  const AutoEqProfile({
    required this.name,
    required this.path,
    required this.author,
    this.target = '',
  });

  final String name;
  final String path;
  final String author;
  final String target;

  String get source => path.split('/').first.replaceAll('%20', ' ');

  String get rawUrl =>
      'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/'
      '$path/ParametricEQ.txt';

  factory AutoEqProfile.fromMarkdown(String line) {
    final match = RegExp(
      r'^- \[(.*?)\]\(\./(.+)\) by (.*?)(?: on (.*))?$',
    ).firstMatch(line);
    if (match == null) {
      return AutoEqProfile(name: '', path: '', author: '');
    }
    return AutoEqProfile(
      name: match.group(1) ?? '',
      path: match.group(2) ?? '',
      author: match.group(3) ?? '',
      target: match.group(4) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'author': author,
        'target': target,
      };

  factory AutoEqProfile.fromJson(Map<String, dynamic> json) => AutoEqProfile(
        name: json['name']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
        author: json['author']?.toString() ?? '',
        target: json['target']?.toString() ?? '',
      );
}

class AutoEqService {
  AutoEqService._();

  static const _indexUrl =
      'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md';
  static const _cacheKey = 'AUTOEQ_INDEX';
  static const _cacheTimeKey = 'AUTOEQ_INDEX_TIME';
  static const _cacheDuration = Duration(days: 7);

  static List<AutoEqProfile> _memory = const [];

  static List<AutoEqProfile> get all => _memory;

  /// Pure parser, unit-testable without network.
  static List<AutoEqProfile> parseIndex(String markdown) => markdown
      .split(RegExp(r'[\r\n]+'))
      .where((line) => line.startsWith('- ['))
      .map(AutoEqProfile.fromMarkdown)
      .where((p) => p.name.isNotEmpty && p.path.isNotEmpty)
      .toList();

  static Future<List<AutoEqProfile>> loadIndex({bool force = false}) async {
    if (_memory.isNotEmpty && !force) return _memory;
    try {
      if (!Hive.isBoxOpen('SETTINGS')) return const [];
      final box = Hive.box('SETTINGS');
      final cached = box.get(_cacheKey);
      final cachedAt = box.get(_cacheTimeKey);
      final fresh = cachedAt is int &&
          DateTime.now().millisecondsSinceEpoch - cachedAt <
              _cacheDuration.inMilliseconds;
      if (!force && fresh && cached is List && cached.isNotEmpty) {
        _memory = cached
            .whereType<Map>()
            .map((m) => AutoEqProfile.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        return _memory;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse(_indexUrl))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return _memory;
      _memory = parseIndex(response.body);
      if (Hive.isBoxOpen('SETTINGS')) {
        await Hive.box('SETTINGS').put(
          _cacheKey,
          _memory.map((p) => p.toJson()).toList(),
        );
        await Hive.box('SETTINGS')
            .put(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('[autoeq] index: $e');
    }
    return _memory;
  }

  static List<AutoEqProfile> search(String query, {int limit = 60}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _memory.take(limit).toList();
    return _memory
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.author.toLowerCase().contains(q) ||
            p.source.toLowerCase().contains(q))
        .take(limit)
        .toList();
  }

  /// Download a profile's ParametricEQ.txt and convert it to our 10 bands.
  static Future<List<double>?> fetchGains(AutoEqProfile profile) async {
    try {
      final response = await http
          .get(Uri.parse(profile.rawUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final gains = AxionEqService.parseAutoEqProfile(response.body);
      return gains.any((g) => g != 0) ? gains : null;
    } catch (e) {
      debugPrint('[autoeq] ${profile.name}: $e');
      return null;
    }
  }
}
