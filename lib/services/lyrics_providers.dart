/// Desktop ports of the Android lyrics providers (`betterlyrics/`,
/// `simpmusic/`, `youlyplus/`, `kugou/`, `paxsenixlyrics/`, `unison/`).
/// All implement `LyricsProvider` from `lyrics_registry.dart`.
library lyrics_providers;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lyrics_registry.dart';

/// TTML → LRC, port of Android `TTMLParser` (simplified: handles `<p>` lines,
/// word-level `<span begin end>` runs, roles `x-bg`/`x-translation`/`x-roman`).
class TtmlParser {
  static double parseTime(String s) {
    final t = s.trim();
    if (!t.contains(':')) return double.tryParse(t) ?? 0;
    final parts = t.split(':');
    if (parts.length == 2) {
      return (double.tryParse(parts[0]) ?? 0) * 60 +
          (double.tryParse(parts[1]) ?? 0);
    }
    if (parts.length == 3) {
      return (double.tryParse(parts[0]) ?? 0) * 3600 +
          (double.tryParse(parts[1]) ?? 0) * 60 +
          (double.tryParse(parts[2]) ?? 0);
    }
    return 0;
  }

  static String lrcTime(double seconds) {
    final ms = (seconds * 1000).round();
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$cs]';
  }

  static String syllableTime(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final rest = ms % 1000;
    return '<${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${rest.toString().padLeft(3, '0')}>';
  }

  /// Parses TTML XML into a LRC string (with `<word:start:end>` word timings).
  static String toLrc(String ttml) {
    final buffer = StringBuffer();
    final pRegex = RegExp(r'<p\b([^>]*)>(.*?)</p>', dotAll: true);
    for (final p in pRegex.allMatches(ttml)) {
      final attrs = p.group(1) ?? '';
      final body = p.group(2) ?? '';
      final begin = RegExp(r'\bbegin="([^"]+)"').firstMatch(attrs)?.group(1);
      if (begin == null) continue;
      final start = parseTime(begin);

      final words = <Map<String, dynamic>>[];
      for (final m in RegExp(r'<span\b([^>]*)>(.*?)</span>', dotAll: true).allMatches(body)) {
        final a = m.group(1) ?? '';
        if (a.contains('x-translation') || a.contains('x-roman')) continue;
        final text = (m.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final wb = RegExp(r'\bbegin="([^"]+)"').firstMatch(a)?.group(1);
        final we = RegExp(r'\bend="([^"]+)"').firstMatch(a)?.group(1);
        if (text.isNotEmpty && wb != null && we != null) {
          words.add({'text': text, 'start': parseTime(wb), 'end': parseTime(we)});
        }
      }
      final lineText = words.isEmpty
          ? body.replaceAll(RegExp(r'<[^>]+>'), '').trim()
          : words.map((w) => w['text']).join(' ');
      if (lineText.isEmpty) continue;
      buffer.writeln('${lrcTime(start)}$lineText');
      if (words.isNotEmpty) {
        buffer.writeln('<${words.map((w) => '${w['text']}:${w['start']}:${w['end']}').join('|')}>');
      }
    }
    return buffer.toString().trim();
  }
}

Future<dynamic> _getJson(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final r = await http.get(uri, headers: headers).timeout(timeout);
    if (r.statusCode != 200) return null;
    if (r.body.trim().isEmpty) return null;
    return jsonDecode(r.body);
  } catch (_) {
    return null;
  }
}

/// Android `betterlyrics/BetterLyrics.kt` — TTML from
/// `https://lyrics-api.boidu.dev/getLyrics`.
class BetterLyricsProvider extends LyricsProvider {
  static const base = 'https://lyrics-api.boidu.dev';
  @override
  String get name => 'BetterLyrics';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final query = <String, String>{'s': title, 'a': artist};
    if (duration > 0) query['d'] = '$duration';
    if (album != null && album.isNotEmpty) query['al'] = album;
    final data = await _getJson(Uri.https('lyrics-api.boidu.dev', '/getLyrics', query));
    final ttml = data?['ttml'];
    if (ttml is! String || ttml.isEmpty) return null;
    final lrc = TtmlParser.toLrc(ttml);
    if (lrc.isEmpty) return null;
    return LyricsProviderResult(syncedLyrics: lrc);
  }
}

/// Android `simpmusic/SimpMusicLyrics.kt`.
class SimpMusicProvider extends LyricsProvider {
  static const primary = 'https://api-lyrics.simpmusic.org/v1/';
  static const fallback = 'https://vivi-yt-music-server.onrender.com/v1/';
  @override
  String get name => 'SimpMusic';

  static List<dynamic> tracksFrom(dynamic data) {
    if (data is Map && data['success'] == true && data['data'] is List) {
      return data['data'] as List;
    }
    return const [];
  }

  static Map<String, dynamic>? pick(List<dynamic> tracks, int duration) {
    final candidates = duration > 0
        ? tracks.where((t) =>
            ((t is Map ? t['duration'] : null) is num) &&
            (((t as Map)['duration'] as num) - duration).abs() <= 10).toList()
        : List.of(tracks);
    if (candidates.isEmpty) return null;
    if (duration > 0 && candidates.length > 1) {
      candidates.sort((a, b) =>
          (((a as Map)['duration'] as num) - duration).abs().compareTo(
              (((b as Map)['duration'] as num) - duration).abs()));
    }
    return candidates.first as Map<String, dynamic>;
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final headers = {
      'Accept': 'application/json',
      'User-Agent': 'SimpMusicLyrics/1.0',
      'Content-Type': 'application/json',
    };
    var data = await _getJson(Uri.parse('$primary$id'), headers: headers);
    var tracks = tracksFrom(data);
    if (tracks.isEmpty) {
      data = await _getJson(Uri.parse('$fallback$id'), headers: headers);
      tracks = tracksFrom(data);
    }
    final best = pick(tracks, duration);
    if (best == null) return null;
    for (final key in ['richSyncLyrics', 'syncedLyrics', 'plainLyrics']) {
      final v = best[key];
      if (v is String && v.trim().isNotEmpty) {
        return LyricsProviderResult(syncedLyrics: key == 'plainLyrics' ? null : v, plainLyrics: key == 'plainLyrics' ? v : null);
      }
    }
    return null;
  }
}

/// Android `youlyplus/YouLyPlus.kt` — races LyricsPlus community servers.
class YouLyPlusProvider extends LyricsProvider {
  static const servers = [
    'https://lyricsplus.prjktla.my.id',
    'https://lyricsplus.atomix.one',
    'https://lyricsplus.binimum.org',
    'https://lyricsplus.prjktla.workers.dev',
    'https://lyricsplus-seven.vercel.app',
    'https://lyrics-plus-backend.vercel.app',
  ];

  /// Converts a LyricsPlus `lyrics` list into word-level LRC.
  static String? convertSyllabus(dynamic lyrics) {
    if (lyrics is! List || lyrics.isEmpty) return null;
    final buffer = StringBuffer();
    for (final item in lyrics) {
      if (item is! Map) continue;
      final time = (item['time'] as num?)?.toInt() ?? 0;
      final syllabus = item['syllabus'];
      final text = item['text'] as String? ?? '';
      if (syllabus is List && syllabus.isNotEmpty) {
        final words = StringBuffer();
        final word = StringBuffer();
        var wordTime = 0;
        void flush() {
          final t = word.toString().trim();
          if (t.isNotEmpty) {
            words.write('${TtmlParser.syllableTime(wordTime)}$t ');
          }
          word.clear();
        }
        for (final s in syllabus) {
          if (s is! Map) continue;
          final st = s['text'] as String? ?? '';
          if (st.startsWith(' ')) flush();
          if (word.isEmpty) wordTime = (s['time'] as num?)?.toInt() ?? 0;
          word.write(st);
          if (st.endsWith(' ')) flush();
        }
        flush();
        buffer.writeln(words.toString().trim());
      } else if (text.isNotEmpty) {
        buffer.writeln('${TtmlParser.syllableTime(time)}${text}');
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  @override
  String get name => 'YouLyPlus';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    for (final server in servers) {
      final uri = Uri.parse('$server/v2/lyrics/get').replace(queryParameters: {
        'title': title,
        'artist': artist,
        'duration': '$duration',
        if (album != null) 'album': album,
        if (id.isNotEmpty) 'id': id,
      });
      final data = await _getJson(uri, timeout: const Duration(seconds: 8));
      if (data == null) continue;
      final synced = data['syncedLyrics'];
      if (synced is String && synced.trim().isNotEmpty) {
        return LyricsProviderResult(syncedLyrics: synced);
      }
      final rich = convertSyllabus(data['lyrics']);
      if (rich != null) return LyricsProviderResult(syncedLyrics: rich);
      final plain = data['plainLyrics'];
      if (plain is String && plain.trim().isNotEmpty) {
        return LyricsProviderResult(plainLyrics: plain);
      }
    }
    return null;
  }
}

/// Android `kugou/KuGou.kt` (ViMusic-derived search → download → normalize).
class KuGouProvider extends LyricsProvider {
  static const durationTolerance = 8;

  static String normalizeTitle(String t) => t
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'\[.*?\]'), '');

  static String normalizeArtist(String a) => a
      .replaceAll(', ', '、')
      .replaceAll(' & ', '、')
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\(.*\)'), '');

  /// Drops header/footer metadata lines (composer, singer, etc.).
  static String normalize(String lrc) {
    final accepted = RegExp(r'^\[\d\d:\d\d\.\d{2,3}\]');
    final banned = RegExp(r'.+].+[:写].+');
    final lines = lrc.split('\n').where((l) => accepted.hasMatch(l)).toList();
    var head = 0;
    for (var i = (lines.length - 1 < 30 ? lines.length - 1 : 30); i >= 0; i--) {
      if (banned.hasMatch(lines[i])) {
        head = i + 1;
        break;
      }
    }
    final filtered = lines.skip(head).toList();
    var tail = 0;
    for (var i = 0; i < filtered.length && i < 30; i++) {
      if (banned.hasMatch(filtered[filtered.length - 1 - i])) {
        tail = i + 1;
        break;
      }
    }
    return filtered.take(filtered.length - tail).join('\n');
  }

  @override
  String get name => 'Kugou';

  Future<List<dynamic>> _searchSongs(String keyword) async {
    final data = await _getJson(
      Uri.https('mobileservice.kugou.com', '/api/v3/search/song', {
        'version': '9108',
        'plat': '0',
        'pagesize': '8',
        'showtype': '0',
        'keyword': keyword,
      }),
    );
    final info = data?['data']?['info'];
    return info is List ? info : const [];
  }

  Future<List<dynamic>> _searchLyrics({String? hash, required String keyword, int? duration}) async {
    final params = <String, String>{
      'ver': '1',
      'man': 'yes',
      'client': 'pc',
      if (hash != null) 'hash': hash,
      if (hash == null) 'keyword': keyword,
      if (hash == null && duration != null && duration > 0) 'duration': '${duration * 1000}',
    };
    final data = await _getJson(Uri.https('lyrics.kugou.com', '/search', params));
    final candidates = data?['candidates'];
    return candidates is List ? candidates : const [];
  }

  Future<String?> _download(Map candidate) async {
    final data = await _getJson(Uri.https('lyrics.kugou.com', '/download', {
      'fmt': 'lrc',
      'charset': 'utf8',
      'client': 'pc',
      'ver': '1',
      'id': '${candidate['id']}',
      'accesskey': '${candidate['accesskey']}',
    }));
    final content = data?['content'];
    if (content is! String || content.isEmpty) return null;
    try {
      return normalize(utf8.decode(base64.decode(content)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final keyword =
        '${normalizeTitle(title)} - ${normalizeArtist(artist)}${album != null && album.isNotEmpty ? ' $album' : ''}';
    final songs = await _searchSongs(keyword);
    for (final song in songs) {
      if (song is! Map) continue;
      final d = song['duration'];
      if (duration > 0 && d is num && ((d - duration).abs() > durationTolerance)) continue;
      final candidates = await _searchLyrics(hash: '${song['hash']}', keyword: '');
      if (candidates.isNotEmpty) {
        final lrc = await _download(candidates.first as Map);
        if (lrc != null && lrc.isNotEmpty) return LyricsProviderResult(syncedLyrics: lrc);
      }
    }
    final candidates = await _searchLyrics(keyword: keyword, duration: duration);
    if (candidates.isNotEmpty) {
      final lrc = await _download(candidates.first as Map);
      if (lrc != null && lrc.isNotEmpty) return LyricsProviderResult(syncedLyrics: lrc);
    }
    return null;
  }
}

/// Android `paxsenixlyrics/Paxsenix.kt` — Apple Music search + scoring.
class PaxsenixProvider extends LyricsProvider {
  static const base = 'https://lyrics.paxsenix.org';

  static List<Map<String, dynamic>> scoreAndFilter(
    List<dynamic> results,
    String title,
    String artist,
    int duration,
  ) {
    final cleanup = RegExp(r'\s*\(.*?\)|\s*\[.*?\]');
    final cleanedTitle = title.replaceAll(cleanup, '').toLowerCase().trim();
    final cleanedArtist = artist.toLowerCase();
    final scored = <Map<String, dynamic>>[];
    for (final r in results) {
      if (r is! Map) continue;
      var score = 0.0;
      final d = r['duration'];
      if (d is num) {
        final diff = (d - duration * 1000).abs();
        if (diff <= 2000) score += 100;
        else if (diff <= 5000) score += 50;
        else if (diff <= 10000) score += 10;
        else score -= 50;
      }
      final name = (r['displayName'] as String? ?? '').replaceAll(cleanup, '').toLowerCase().trim();
      if (name == cleanedTitle) score += 80;
      else if (name.contains(cleanedTitle) || cleanedTitle.contains(name)) score += 40;
      final da = (r['displayArtist'] as String? ?? '').toLowerCase();
      if (da.contains(cleanedArtist)) score += 50;
      else if (cleanedArtist.split(RegExp(r'\s+')).where((w) => w.length > 2).any(da.contains)) score += 25;
      if (score > 0) scored.add({'result': r, 'score': score});
    }
    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scored.take(10).toList();
  }

  @override
  String get name => 'Paxsenix';

  Future<List<dynamic>> _search(String q) async {
    final data = await _getJson(Uri.parse('$base/apple-music/search?q=${Uri.encodeComponent(q)}'),
        headers: {'User-Agent': 'echomusic/1.0'});
    return data is List ? data : <dynamic>[];
  }

  Future<String?> _fetch(String id) async {
    final data = await _getJson(Uri.parse('$base/apple-music/lyrics?id=${Uri.encodeComponent(id)}'),
        headers: {'User-Agent': 'echomusic/1.0'});
    if (data == null) return null;
    final ttml = data['ttmlContent'];
    if (ttml is String && ttml.isNotEmpty) {
      final lrc = TtmlParser.toLrc(ttml);
      if (lrc.isNotEmpty) return lrc;
    }
    for (final key in ['elrcMultiPerson', 'elrc', 'plain']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    final content = data['content'];
    if (content is! List || content.isEmpty) return null;
    final buffer = StringBuffer();
    for (final line in content) {
      if (line is! Map) continue;
      final time = (line['timestamp'] as num?)?.toInt() ?? 0;
      final words = line['text'];
      final text = words is List
          ? words.map((w) => w is Map ? (w['text'] as String? ?? '') : '').join(' ')
          : '';
      if (text.trim().isEmpty) continue;
      final agent = line['background'] == true
          ? '{bg}'
          : line['oppositeTurn'] == true
              ? '{agent:v2}'
              : '{agent:v1}';
      buffer.writeln('${TtmlParser.lrcTime(time / 1000)}$agent$text');
      if (data['type'] == 'Syllable' && words is List) {
        buffer.writeln('<${words.map((w) {
          final m = w is Map ? w : <String, dynamic>{};
          return '${m['text']}:${((m['timestamp'] as num?) ?? 0) / 1000}:${((m['endtime'] as num?) ?? 0) / 1000}';
        }).join('|')}>');
      }
    }
    final lrc = buffer.toString().trim();
    return lrc.isEmpty ? null : lrc;
  }

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final queries = <String>[
      '$title $artist',
      title,
      if (album != null && album.isNotEmpty) '$title $artist $album',
    ];
    List<dynamic> results = const [];
    List<Map<String, dynamic>> scored = const [];
    for (final q in queries) {
      results = await _search(q);
      if (results.isEmpty) continue;
      scored = scoreAndFilter(results, title, artist, duration);
      if (scored.isNotEmpty) break;
    }
    String? fallback;
    for (final s in scored.take(5)) {
      final lrc = await _fetch('${(s['result'] as Map)['id']}');
      if (lrc == null || lrc.isEmpty) continue;
      if (lrc.contains('<') && lrc.contains('>')) {
        return LyricsProviderResult(syncedLyrics: lrc);
      }
      fallback ??= lrc;
    }
    if (fallback != null) return LyricsProviderResult(syncedLyrics: fallback);
    return null;
  }
}

/// Android `unison/Unison.kt` — single API with videoId/metadata lookup.
class UnisonProvider extends LyricsProvider {
  static const base = 'https://unison.boidu.dev/';

  Future<Map<String, dynamic>?> _get(Map<String, String> query) async {
    final data = await _getJson(
      Uri.parse(base).replace(path: '/lyrics', queryParameters: query),
      timeout: const Duration(seconds: 15),
    );
    if (data == null || data['success'] != true) return null;
    final entry = data['data'];
    if (entry is Map && entry['lyrics'] is String && (entry['lyrics'] as String).isNotEmpty) {
      return entry.cast<String, dynamic>();
    }
    return null;
  }

  @override
  String get name => 'Unison';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    if (title.trim().isEmpty || artist.trim().isEmpty) return null;
    Map<String, dynamic>? entry;
    if (id.isNotEmpty) entry = await _get({'v': id});
    entry ??= await _get({
      'song': title,
      'artist': artist,
      if (album != null && album.isNotEmpty) 'album': album,
      if (duration > 0) 'duration': '$duration',
    });
    if (entry == null) return null;
    var lrc = entry['lyrics'] as String;
    if (lrc.trimLeft().toLowerCase().startsWith('<tt')) {
      lrc = TtmlParser.toLrc(lrc);
    }
    return LyricsProviderResult(syncedLyrics: lrc);
  }
}
