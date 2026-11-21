import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'lyrics_registry.dart';

/// Extra lyric sources beyond the Android registry: a second synced source
/// (Netease Cloud Music), a plain-text fallback (AZLyrics) and local `.lrc`
/// files. They are tried by [LyricsService] in that order.

/// True when [text] contains at least one `[mm:ss.xx]` timestamp.
bool isLrc(String text) =>
    RegExp(r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]').hasMatch(text);

class NeteaseProvider extends LyricsProvider {
  static const _base = 'https://music.163.com';
  static const _headers = {
    'Referer': _base,
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36',
  };

  @override
  String get name => 'Netease';

  static List<dynamic> songsFrom(dynamic data) {
    if (data is! Map) return const [];
    final songs = data['result']?['songs'];
    return songs is List ? songs : const [];
  }

  static String? firstId(List<dynamic> songs) {
    if (songs.isEmpty) return null;
    final first = songs.first;
    if (first is! Map) return null;
    final id = first['id'];
    return id == null ? null : id.toString();
  }

  Future<dynamic> _get(Uri uri) async {
    final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final keyword = artist.isEmpty ? title : '$artist $title';
    final search = await _get(Uri.https('music.163.com', '/api/search/get', {
      's': keyword,
      'type': '1',
      'offset': '0',
      'limit': '5',
    }));
    final songId = firstId(songsFrom(search));
    if (songId == null) return null;
    final data = await _get(Uri.https('music.163.com', '/api/song/lyric', {
      'id': songId,
      'lv': '1',
      'kv': '1',
      'tv': '-1',
    }));
    if (data is! Map) return null;
    final lrc = data['lrc']?['lyric']?.toString() ?? '';
    if (lrc.isEmpty) return null;
    return LyricsProviderResult(
      syncedLyrics: isLrc(lrc) ? lrc : null,
      plainLyrics: isLrc(lrc) ? null : lrc,
    );
  }
}

class AzLyricsProvider extends LyricsProvider {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36',
  };

  @override
  String get name => 'AZLyrics';

  /// AZLyrics' URL convention: lowercase alphanumeric slug, no spaces.
  static String slug(String value) {
    final cleaned = value
        .replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase()
        .trim();
    return cleaned.replaceAll(' ', '');
  }

  /// Extract the lyrics div and strip tags/entities. Pure helper.
  static String? extractLyrics(String html) {
    final match = RegExp(
      r'<div[^>]*class="lyrics"[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    var text = match.group(1) ?? '';
    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    for (final entry in {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
    }.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    if (artist.isEmpty) return null;
    final uri = Uri.https('www.azlyrics.com', '/lyrics/${slug(artist)}/${slug(title)}.html');
    try {
      final r = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final lyrics = extractLyrics(r.body);
      return lyrics == null ? null : LyricsProviderResult(plainLyrics: lyrics);
    } catch (_) {
      return null;
    }
  }
}

class LocalLrcProvider extends LyricsProvider {
  @override
  String get name => 'LocalLRC';

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<Directory> _folder() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/lyrics');
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    try {
      final folder = await _folder();
      if (!folder.existsSync()) return null;
      final wanted = normalize(title);
      final byArtist = normalize(artist);
      final candidates = folder
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.lrc'))
          .where((f) {
            final name = normalize(f.uri.pathSegments.last.replaceAll('.lrc', ''));
            return name.contains(wanted) ||
                (byArtist.isNotEmpty && name.contains(byArtist));
          })
          .toList();
      if (candidates.isEmpty) return null;
      final content = await candidates.first.readAsString();
      if (content.trim().isEmpty) return null;
      return LyricsProviderResult(
        syncedLyrics: isLrc(content) ? content : null,
        plainLyrics: isLrc(content) ? null : content,
      );
    } catch (_) {
      return null;
    }
  }
}
