import 'package:Echo/services/lrcnet_api.dart';
import 'package:Echo/services/lyrics_registry.dart';

/// Desktop adapter of Android's `LrcLibLyricsProvider`
/// (`lyrics/LrcLibLyricsProvider.kt`), backed by the already-ported
/// `lib/services/lrcnet_api.dart` (`getLRCNetAPILyrics`).
///
/// On desktop the LRCLIB provider is always on; the enable/disable keys of
/// Android (`EnableLrcLibKey`, DataStore) are not needed — the same behaviour
/// as desktop's `LyricsService`.
class LrcLibProvider extends LyricsProvider {
  @override
  String get name => 'LrcLib';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final lyrics = await getLRCNetAPILyrics(title,
        artist: artist, album: album, duration: duration.toString());
    if (lyrics == null) return null;
    return LyricsProviderResult(
      syncedLyrics: lyrics.lyricsSynced,
      plainLyrics: lyrics.lyricsPlain,
    );
  }
}
