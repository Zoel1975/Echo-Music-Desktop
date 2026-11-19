/// Serializable snapshot of the playing queue.
///
/// Port of Android's queue persistence (`Queue`/`MusicService` state): the
/// desktop saves the full ordered list of songs, the current index, the
/// playback position and whether playback was active, so a restart restores
/// the same queue instead of only the last track.
class QueueSnapshot {
  const QueueSnapshot({
    required this.songs,
    required this.index,
    required this.positionMs,
    required this.wasPlaying,
  });

  final List<Map<String, dynamic>> songs;
  final int index;
  final int positionMs;
  final bool wasPlaying;

  bool get isValid => songs.isNotEmpty && index >= 0 && index < songs.length;

  Map<String, dynamic> toMap() => {
        'songs': songs,
        'index': index,
        'position': positionMs,
        'playing': wasPlaying,
      };

  factory QueueSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['songs'];
    final songs = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final song in raw) {
        if (song is Map) songs.add(Map<String, dynamic>.from(song));
      }
    }
    return QueueSnapshot(
      songs: songs,
      index: (map['index'] as num?)?.toInt() ?? 0,
      positionMs: (map['position'] as num?)?.toInt() ?? 0,
      wasPlaying: map['playing'] as bool? ?? false,
    );
  }
}
