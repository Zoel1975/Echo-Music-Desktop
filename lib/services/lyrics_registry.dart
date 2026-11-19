/// Port of Android `lyrics/LyricsProvider.kt` + `lyrics/LyricsProviderRegistry.kt`
/// (`LyricsProviderRegistry`, `ProviderOutcome`, `ProviderChoice`, `LyricsProvider`).
library lyrics_registry;

/// Abstract shape of a lyrics source. Port of the Android
/// `LyricsProvider` interface.
abstract class LyricsProvider {
  /// Registry name of the provider, e.g. "LrcLib".
  String get name;

  /// Result of a lookup, or `null` when unavailable.
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  });
}

class LyricsProviderResult {
  final String? syncedLyrics;
  final String? plainLyrics;

  const LyricsProviderResult({this.syncedLyrics, this.plainLyrics});
}

enum ProviderOutcome { synced, unsynced, failed }

/// Outcome of the "choose provider" pass over an ordered provider list.
/// Android: `ProviderChoice.Pending / Selected(name) / None`.
class ProviderSelection {
  const ProviderSelection._(this.name, this.pending, this.none);

  final String? name;
  final bool pending;
  final bool none;
}

class LyricsProviderRegistry {
  static const Map<String, String> providerDisplayNames = {
    'YouLyPlus': 'YouLyPlus',
    'Paxsenix': 'Paxsenix',
    'BetterLyrics': 'Better Lyrics',
    'Unison': 'Unison',
    'SimpMusic': 'SimpMusic',
    'LrcLib': 'LrcLib',
    'Kugou': 'KuGOU',
    'YouTubeSubtitle': 'YouTube Subtitle',
    'YouTubeMusic': 'YouTube Music',
  };

  /// Provider order: the Android default order, with the desktop-implemented
  /// LRC first. See `lib/services/lyrics.dart`.
  static const List<String> defaultOrder = [
    'LrcLib',
    'YouLyPlus',
    'Paxsenix',
    'Unison',
    'BetterLyrics',
    'SimpMusic',
    'Kugou',
    'YouTubeSubtitle',
    'YouTubeMusic',
  ];

  static const List<String> providerNames = [
    'YouLyPlus',
    'Paxsenix',
    'BetterLyrics',
    'Unison',
    'SimpMusic',
    'LrcLib',
    'Kugou',
    'YouTubeSubtitle',
    'YouTubeMusic',
  ];

  static String displayName(String name) =>
      providerDisplayNames[name] ?? name;

  /// First provider with a non-failed outcome wins; `pending` when a
  /// provider in the list is still being queried; `none` when all failed.
  static ProviderSelection chooseProvider(
    Iterable<String> order,
    Map<String, ProviderOutcome?> outcomes,
  ) {
    for (final name in order) {
      final outcome = outcomes[name];
      if (outcome == null) {
        return const ProviderSelection._(null, true, false);
      }
      if (outcome == ProviderOutcome.failed) continue;
      return ProviderSelection._(name, false, false);
    }
    return const ProviderSelection._(null, false, true);
  }
}
