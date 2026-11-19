import '../models/lyrics_model.dart' as model;
import 'lrcnet_api.dart';
import 'lyrics_provider_lrc.dart';
import 'lyrics_providers.dart';
import 'lyrics_providers_youtube.dart';
import 'lyrics_registry.dart';

class LyricsService {
  /// Android default provider order (`LyricsProviderRegistry`), with the
  /// desktop-implemented LRC first.
  static final List<LyricsProvider> providers = [
    LrcLibProvider(),
    YouLyPlusProvider(),
    PaxsenixProvider(),
    UnisonProvider(),
    BetterLyricsProvider(),
    SimpMusicProvider(),
    KuGouProvider(),
    YouTubeSubtitleProvider(),
    YouTubeMusicProvider(),
  ];

  Future<model.Lyrics> getLyrics({
    required String title,
    String? artist,
    String? album,
    String? duration,
  }) async {
    final seconds = int.tryParse(duration ?? '') ?? -1;
    for (final provider in providers) {
      try {
        final result = await provider.getLyrics(
          id: '',
          title: title,
          artist: artist ?? '',
          duration: seconds,
          album: album,
        );
        if (result == null) continue;
        if ((result.syncedLyrics == null || result.syncedLyrics!.isEmpty) &&
            (result.plainLyrics == null || result.plainLyrics!.isEmpty)) {
          continue;
        }
        return model.Lyrics(
          artist: artist ?? '',
          title: title,
          album: album,
          duration: duration,
          id: '',
          provider: model.LyricsProvider.lrcnet,
          lyricsPlain: result.plainLyrics ?? '',
          lyricsSynced: result.syncedLyrics,
        );
      } catch (_) {
        // Provider failed — try the next one in the Android registry order.
      }
    }
    // Last-resort fallback: LRCLIB search used by the original desktop app.
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
