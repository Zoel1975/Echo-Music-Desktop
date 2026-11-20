/// Pure helpers for Android `LibrarySongsScreen` / `LibraryAlbumsScreen` /
/// `LibraryArtistsScreen`: aggregate the locally stored songs (favourites +
/// history) into song / album / artist collections. No Flutter dependency.
class LibraryAggregation {
  LibraryAggregation._();

  /// Returns de-duplicated songs keyed by videoId.
  static List<Map<String, dynamic>> allSongs(Iterable<dynamic> sources) {
    final byId = <String, Map<String, dynamic>>{};
    for (final source in sources) {
      if (source is! Map) continue;
      final songs = source['songs'];
      if (songs is! Iterable) continue;
      for (final s in songs) {
        if (s is! Map) continue;
        final id = (s['videoId'] ?? s['id'])?.toString();
        if (id == null || id.isEmpty) continue;
        byId.putIfAbsent(id, () => Map<String, dynamic>.from(s));
      }
    }
    return byId.values.toList();
  }

  static List<Map<String, dynamic>> songList(Iterable<dynamic> rawSongs) {
    final byId = <String, Map<String, dynamic>>{};
    for (final s in rawSongs) {
      if (s is! Map) continue;
      final id = (s['videoId'] ?? s['id'])?.toString();
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => Map<String, dynamic>.from(s));
    }
    return byId.values.toList();
  }

  static String? artistName(dynamic song) {
    final artists = song is Map ? song['artists'] : null;
    if (artists is List && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map) return first['name']?.toString();
      return first?.toString();
    }
    return null;
  }

  static String? _albumName(dynamic song) {
    final album = song is Map ? song['album'] : null;
    if (album is Map) return album['name']?.toString();
    return album?.toString();
  }

  /// Groups songs into albums: {name, artist, songs, thumbnails}.
  static List<Map<String, dynamic>> albums(Iterable<dynamic> rawSongs) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final s in rawSongs) {
      final name = _albumName(s);
      if (name == null || name.isEmpty) continue;
      final entry = grouped.putIfAbsent(name, () => {
            'name': name,
            'artist': artistName(s) ?? '',
            'songs': <Map<String, dynamic>>[],
          });
      (entry['songs'] as List).add(Map<String, dynamic>.from(s as Map));
    }
    return grouped.values.toList()
      ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
  }

  /// Groups songs into artists: {name, songs}.
  static List<Map<String, dynamic>> artists(Iterable<dynamic> rawSongs) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final s in rawSongs) {
      final name = artistName(s);
      if (name == null || name.isEmpty) continue;
      final entry = grouped.putIfAbsent(name, () => {
            'name': name,
            'songs': <Map<String, dynamic>>[],
          });
      (entry['songs'] as List).add(Map<String, dynamic>.from(s as Map));
    }
    return grouped.values.toList()
      ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
  }

  static List<Map<String, dynamic>> filter(
    Iterable<Map<String, dynamic>> items,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items.toList();
    return items.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final name = item['name']?.toString().toLowerCase() ?? '';
      return title.contains(q) || name.contains(q);
    }).toList();
  }
}

