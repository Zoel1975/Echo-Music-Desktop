import 'package:hive/hive.dart';

/// Android's automatic library playlists, built from data already collected
/// on desktop instead of being empty placeholders:
///
/// * **Top** — most played songs from the local `SONG_HISTORY` box.
/// * **Bottom** — least played songs (the usual Android "underplayed" list).
/// * **Cached** — songs available offline from the `DOWNLOADS` box.
class AutoPlaylists {
  AutoPlaylists._();

  static const _historyBox = 'SONG_HISTORY';
  static const _downloadsBox = 'DOWNLOADS';

  static List<Map<String, dynamic>> _songs(String boxName) {
    if (!Hive.isBoxOpen(boxName)) return const [];
    return Hive.box(boxName).values.whereType<Map>().map((m) {
      return Map<String, dynamic>.from(m as Map);
    }).toList();
  }

  /// Most played tracks, highest `plays` first.
  static List<Map<String, dynamic>> top({int limit = 50}) {
    final songs = _songs(_historyBox).where((s) => s['videoId'] != null).toList();
    songs.sort((a, b) => _plays(b).compareTo(_plays(a)));
    return songs.take(limit).toList();
  }

  /// Least played tracks (played at least once), lowest `plays` first.
  static List<Map<String, dynamic>> bottom({int limit = 50}) {
    final songs = _songs(_historyBox)
        .where((s) => s['videoId'] != null && _plays(s) > 0)
        .toList();
    songs.sort((a, b) => _plays(a).compareTo(_plays(b)));
    return songs.take(limit).toList();
  }

  /// Songs that are physically available offline.
  static List<Map<String, dynamic>> cached() => _songs(_downloadsBox)
      .where((s) => s['status'] == 'DOWNLOADED' && s['path'] != null)
      .toList();

  static int _plays(Map<String, dynamic> song) {
    final value = song['plays'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
