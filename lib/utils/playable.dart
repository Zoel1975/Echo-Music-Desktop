/// Converts InnerTube section items (from `handleContents`,
/// `handlePlaylistPanelVideoRenderer`) into the map shape the desktop
/// playback layer expects (`MediaPlayer.playSong`).
///
/// The two layers use different shapes: YTMusic items carry `artists` as a
/// list of `{name, endpoint}`, `album` as `{name, endpoint}`, while
/// `MediaPlayer` expects `artists` as a list of `{name}` and an `album`
/// map with `name`.
library playable;

/// Converts one item to a playable song.
Map<String, dynamic> toPlaySong(dynamic item) {
  final Map<String, dynamic> result = <String, dynamic>{
    'videoId': item['videoId'],
    'title': item['title'],
    'thumbnails': item['thumbnails'],
    'subtitle': item['subtitle'],
    'duration': item['duration'],
  };

  final album = item['album'];
  if (album != null) result['album'] = album;

  final artists = item['artists'];
  if (artists is List && artists.isNotEmpty) {
    result['artists'] = artists
        .map((a) => <String, dynamic>{'name': _artistName(a)})
        .toList();
  } else {
    // Fallback: derive artist names from `subtitle` ("Artist • Album").
    final subtitle = item['subtitle'];
    if (subtitle is String && subtitle.contains('•')) {
      result['artists'] = [
        <String, dynamic>{'name': subtitle.split('•').first.trim()},
      ];
    } else {
      result['artists'] = const <dynamic>[];
    }
  }

  return result;
}

String _artistName(dynamic a) {
  if (a is Map<String, dynamic>) {
    final name = a['name'];
    if (name is String) return name;
    final text = a['text'];
    return text is String ? text : '';
  }
  return a.toString();
}

/// Converts a list of section items to playable songs.
List<Map<String, dynamic>> toPlaySongs(List items) {
  return items.map(toPlaySong).toList();
}
