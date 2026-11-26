import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/lyrics_registry.dart';

void main() {
  group('LyricsProviderRegistry', () {
    test('defaultOrder mirrors the Android order, LrcLib first', () {
      expect(
        LyricsProviderRegistry.defaultOrder,
        [
          'LrcLib',
          'Netease',
          'AZLyrics',
          'LocalLRC',
          'YouLyPlus',
          'Paxsenix',
          'Unison',
          'BetterLyrics',
          'SimpMusic',
          'Kugou',
          'YouTubeSubtitle',
          'YouTubeMusic',
        ],
      );
    });

    test('displayName matches the Android display names', () {
      expect(LyricsProviderRegistry.displayName('LrcLib'), 'LrcLib');
      expect(LyricsProviderRegistry.displayName('Kugou'), 'KuGOU');
      expect(LyricsProviderRegistry.displayName('Unknown'), 'Unknown');
    });

    test('chooseProvider selects the first non-failed provider', () {
      final sel = LyricsProviderRegistry.chooseProvider(
        ['LrcLib', 'Paxsenix'],
        const {'LrcLib': ProviderOutcome.failed, 'Paxsenix': ProviderOutcome.synced},
      );
      expect(sel.name, 'Paxsenix');
      expect(sel.pending, isFalse);
      expect(sel.none, isFalse);
    });

    test('chooseProvider is pending while a provider is still running', () {
      final sel = LyricsProviderRegistry.chooseProvider(
        ['LrcLib'],
        const {'LrcLib': null},
      );
      expect(sel.pending, isTrue);
    });

    test('chooseProvider is none when every provider failed', () {
      final sel = LyricsProviderRegistry.chooseProvider(
        ['LrcLib'],
        const {'LrcLib': ProviderOutcome.failed},
      );
      expect(sel.none, isTrue);
      expect(sel.name, isNull);
    });
  });
}
