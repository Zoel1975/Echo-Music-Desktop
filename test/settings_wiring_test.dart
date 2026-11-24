import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('every disabled setting documents why it cannot work on Windows', () {
    final registry = src('lib/services/settings_capabilities.dart');
    final entries = RegExp(r"^\s*'([A-Za-z0-9_]+)':\s*'([^']+)'", multiLine: true)
        .allMatches(registry)
        .toList();
    expect(entries.length, greaterThanOrEqualTo(5));
    for (final m in entries) {
      expect(m.group(2)!.trim().length, greaterThan(15),
          reason: '${m.group(1)} needs a real explanation');
    }
  });

  test('formerly dead player settings now have real consumers', () {
    final player = src('lib/services/media_player.dart');
    final main = src('lib/main.dart');
    final history = src('lib/utils/add_history.dart');
    final router = src('lib/utils/router.dart');
    final lyrics = src('lib/screens/player/widgets/lyrics_box.dart');
    final search = src('lib/ytmusic/mixins/search.dart');
    final helpers = src('lib/ytmusic/helpers.dart');
    final library = src('lib/screens/library/library_page.dart');
    final bottom = src('lib/screens/shell/widgets/bottom_player.dart');
    final page = src('lib/screens/player/player_page.dart');
    final like = src('lib/screens/player/player_page.dart');

    expect(player, contains('preventDuplicates'));
    expect(player, contains('_restoreQueuePreferences'));
    expect(player, contains('autoLoadMore'));
    expect(player, contains('crossfadeGapless'));
    expect(history, contains('trimLocalHistory'));
    expect(main, contains("Hive.box('SETTINGS').get('PRELOAD_NEXT'"));
    expect(router, contains('_applyDefaultTab'));
    expect(lyrics, contains('_maybeAutoRomanize'));
    expect(lyrics, contains('lyricsAutoScroll'));
    expect(lyrics, contains('lyricsTextPosition'));
    expect(search, contains('_applyContentFilters'));
    expect(helpers, contains('CONTENT_LANGUAGE'));
    expect(helpers, contains('CONTENT_COUNTRY'));
    expect(library, contains('showLikedPlaylist'));
    expect(bottom, contains('miniPlayerStyle'));
    expect(page, contains('hidePlayerThumbnail'));
    expect(like, contains('autoDownloadOnLike'));
  });

  test('appearance options are implemented, not disabled', () {
    final registry = src('lib/services/settings_capabilities.dart');
    for (final key in [
      'hideVolumeSlider',
      'wavyPlayPause',
      'cropArt',
      'rotatingThumb',
      'buttonColors',
      'glassPlayer',
      'glassMiniPlayer',
      'glassNavBar',
      'lyricsAnimation',
      'appleLyricsBlur',
      'standardLyricsBlur',
      'lyricsClickChange',
      'lyricsSwipe',
      'lyricsThumbPlayPause',
      'defaultLibChip',
      'displayDensity',
      'swipeChangeSong',
      'swipeSensitivity',
      'swipeQueue',
      'swipeRemove',
      'lastfmLikes',
      'songDnaEnabled',
      'cloudSync',
      'ltServer',
      'ltAutoApprove',
      'preferExtension',
      'extensionServer',
      'navBarStyle',
      'appleInspired',
      'listenTogetherTop',
      'showTopPlaylist',
      'showBottomPlaylist',
      'showCachedPlaylist',
    ]) {
      expect(registry, isNot(contains("'$key':")),
          reason: '$key is implemented and must not be disabled');
    }
  });

  test('accent color and AMOLED are applied to the theme', () {
    final main = src('lib/main.dart');
    final theme = src('lib/themes/theme.dart');
    expect(main, contains('primary: settings.accentColor'));
    expect(main, contains('amoled: settings.amoledBlack'));
    expect(theme, contains('amoled'));
    expect(theme, contains('surface: Colors.black'));
  });

  test('appearance widgets rebuild when a setting changes', () {
    // Previously the widgets read GetIt without listening, so toggling
    // rotation / glass did nothing until a full app restart.
    expect(src('lib/screens/player/player_page.dart'),
        contains('context.watch<SettingsManager>()'));
    for (final path in [
      'lib/screens/shell/widgets/bottom_player.dart',
      'lib/core/widgets/floating_nav.dart',
      'lib/screens/player/widgets/player_background.dart',
    ]) {
      expect(src(path), contains('AnimatedBuilder'),
          reason: '$path must listen to SettingsManager');
    }
    expect(src('lib/screens/player/widgets/player_background.dart'),
        contains("extra<bool>('glassPlayer'"));
  });

  test('the default UI and catalog language is English', () {
    final manager = src('lib/services/settings_manager.dart');
    final helpers = src('lib/ytmusic/helpers.dart');
    expect(manager, contains("defaultValue: 'en')"),
        reason: 'fresh installs must start in English');
    expect(manager, isNot(contains("defaultValue: 'en-IN'")));
    expect(helpers, contains("defaultValue: 'en')"));
    expect(helpers, isNot(contains("defaultValue: 'en-IN'")));
  });

  test('unportable toggles are disabled with an explicit note in the UI', () {
    final details =
        src('lib/screens/settings/appearance/appearance_details_page.dart');
    final integration =
        src('lib/screens/settings/integrations/integration_page.dart');
    final appearance =
        src('lib/screens/settings/appearance/appearance_page.dart');
    expect(details, contains('Non disponibile su Windows'));
    expect(integration, contains('Non disponibile su Windows'));
    for (final f in [details, integration, appearance]) {
      expect(f, contains('unavailableReason'));
    }
    expect(details, contains('if (reason != null)'));
    expect(integration, contains('if (reason != null)'));
  });
}
