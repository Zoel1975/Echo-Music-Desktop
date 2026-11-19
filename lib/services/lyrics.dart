import '../models/lyrics_model.dart' as model;
import 'lrcnet_api.dart';
import 'lyrics_provider_lrc.dart';
import 'lyrics_providers.dart';
import 'lyrics_providers_youtube.dart';
import 'lyrics_registry.dart';
import 'lyrics_translation.dart' as translation;

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

  /// Translation helper (cache + status), port of Android
  /// `LyricsTranslationHelper`.
  final translation.LyricsTranslationHelper translationHelper =
      translation.LyricsTranslationHelper();

  /// Translates lyric lines with any provider (DeepL, Mistral, OpenRouter /
  /// ApiRoute) using the Android orchestration + cache.
  Future<List<String>> translateLyrics({
    required List<String> lines,
    required String targetLanguage,
    required String mode,
    required String provider,
    required String apiKey,
    String baseUrl = '',
    String model = '',
    String deeplApiKey = '',
    String deeplFormality = 'default',
    bool useStreaming = true,
    void Function(List<String>)? onPartial,
  }) {
    return translation.translateLyrics(
      lines: lines,
      targetLanguage: targetLanguage,
      mode: mode,
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      deeplApiKey: deeplApiKey,
      deeplFormality: deeplFormality,
      useStreaming: useStreaming,
      helper: translationHelper,
      onPartial: onPartial,
    );
  }

  /// Desktop port of Android's `LyricsProviderRegistry` name/display table.
  static List<String> getProviderNames() => LyricsProviderRegistry.providerNames;
}
