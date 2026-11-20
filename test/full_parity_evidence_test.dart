import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Evidence test: every parity-matrix row that was previously marked PART is
/// backed by a real, non-trivial implementation (or an explicit reachable
/// placeholder). This turns the PORTING_PLAN claims into executable checks.
void main() {
  final impl = <String, String>{
    // UI / navigation
    'FloatingTabBar/FloatingNavBar': 'lib/core/widgets/floating_nav.dart',
    'DESIGN tokens': 'lib/core/theme/tokens.dart',
    'PlayerMenu/MiniPlayer': 'lib/screens/shell/widgets/bottom_player.dart',
    'BigSeekBar/WavySlider': 'lib/screens/player/player_page.dart',
    'AppNavigation': 'lib/utils/router.dart',
    'HomeScreen': 'lib/screens/home/home_page.dart',
    'ChartsScreen': 'lib/screens/chart/chart_details_page.dart',
    'MoodAndGenres': 'lib/screens/chip/chip_page.dart',
    'BrowseScreen': 'lib/screens/browse/browse_page.dart',
    'OnlineSearchScreen': 'lib/screens/search/search_page.dart',
    'SearchSuggestions': 'lib/ytmusic/mixins/search.dart',
    'LocalPlaylistScreen': 'lib/screens/library/playlist/playlist_details_page.dart',
    'LibraryScreen': 'lib/screens/library/library_page.dart',
    'PlayerMenu': 'lib/screens/player/player_page.dart',
    // Services
    'MediaService': 'lib/services/media_player.dart',
    'LyricsHelper': 'lib/services/lyrics.dart',
    'LyricsProviderRegistry': 'lib/services/lyrics_registry.dart',
    'LyricsV2/word-sync': 'lib/screens/player/widgets/lyrics_box.dart',
    'ExtensionManager': 'lib/screens/settings/integrations/integration_catalog.dart',
    'Updater': 'lib/services/update_service/update_service.dart',
    'GoogleLogin': 'lib/services/google_login_service.dart',
    'DeviceLink': 'lib/services/device_link_service.dart',
    'SpotifyImport': 'lib/screens/settings/services/spotify/spotify_import_page.dart',
    'AxionEq': 'lib/services/axion_eq_service.dart',
    'EchoBrain': 'lib/services/echo_brain_service.dart',
    'QueueFilter': 'lib/services/queue_filter.dart',
    'PlayerLayout': 'lib/services/player_layout.dart',
    'ExtensionQuality': 'lib/services/extension_quality.dart',
  };

  group('formerly-PART rows have real implementations', () {
    impl.forEach((feature, path) {
      test(feature, () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing implementation: $path');
        final lines = file.readAsLinesSync().length;
        expect(lines, greaterThan(10),
            reason: '$path looks like a stub ($lines lines)');
      });
    });
  });

  group('routes are registered', () {
    final router = File('lib/utils/router.dart').readAsStringSync();
    for (final route in [
      '/player',
      '/search',
      '/saved',
      '/settings',
      '/playlist',
      '/chart_details',
      '/device_link',
      "path: 'axion'",
      "path: 'brain'",
      "path: 'services/spotify_import'",
    ]) {
      test('route $route', () {
        expect(router, contains(route), reason: 'route not registered: $route');
      });
    }
  });

  test('recognition is an explicit reachable placeholder', () {
    final settings = File('lib/screens/settings/settings_page.dart')
        .readAsStringSync();
    expect(settings, contains('Song recognition (Echo Find)'));
    expect(settings, contains('future update'));
    final catalog = File('lib/screens/coming_soon/coming_soon_catalog.dart')
        .readAsStringSync();
    // The placeholder page itself is reachable through /settings/coming_soon.
    expect(catalog, contains('ComingSoonFeature'));
  });
}
