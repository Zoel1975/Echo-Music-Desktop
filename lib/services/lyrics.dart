import '../models/lyrics_model.dart';
import 'lrcnet_api.dart';
import 'lyrics_registry.dart';

class LyricsService {
  Future<Lyrics> getLyrics({
    required String title,
    String? artist,
    String? album,
    String? duration,
  }) async {
    // The LRCLIB provider (Android's `LrcLibLyricsProvider` port) is backed by
    // `getLRCNetAPILyrics`. Other Android providers (Kugou, BetterLyrics,
    // SimpMusic, YouLyPlus, Paxsenix, Unison, YouTube) are not yet ported —
    // see docs/PORTING_PLAN.md §9.
    return await getLRCNetAPILyrics(
      title,
      artist: artist,
      album: album,
      duration: duration,
    );
  }

  /// Desktop port of Android's `LyricsProviderRegistry` name/display table.
  static List<String> getProviderNames() => LyricsProviderRegistry.providerNames;
}
