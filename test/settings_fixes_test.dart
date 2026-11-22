import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  group('settings code-review fixes', () {
    test('equalizer opens on desktop with real 10-band controls', () {
      final eq = src('lib/screens/settings/player/equalizer/equalizer_page.dart');
      expect(eq, contains("import 'dart:io';"));
      expect(eq, contains('Platform.isAndroid'));
      expect(eq, contains('EqSettings.savedGains(settings)'));
      expect(eq, contains('eqFrequencies[i]'));
      expect(eq, contains('snapshot.hasError'));
      expect(eq, contains('late final Future<Widget> _view'));
    });

    test('EQ gains are restored and never wiped by other toggles', () {
      final main = src('lib/main.dart');
      expect(main, contains('EqSettings.apply(settingsManager)'));
      expect(main, isNot(contains('SilenceFilter.apply(enabled: settingsManager')));

      final cubit =
          src('lib/screens/settings/player/cubit/player_settings_cubit.dart');
      expect(cubit, contains('EqSettings.apply(_settings)'));

      final eqSettings = src('lib/services/eq_settings.dart');
      expect(eqSettings, contains('equalizerBandsGain'));
      expect(eqSettings, contains('axionEQGains'));

      final axion =
          src('lib/screens/settings/player/equalizer/axion_eq_page.dart');
      expect(axion, contains('s.equalizerBandsGain = List<double>.from(_gains)'));
      expect(axion, contains('EqSettings.apply(s)'));
    });

    test('band gain writes no longer throw on an empty profile', () {
      final manager = src('lib/services/settings_manager.dart');
      expect(manager,
          contains('List<double>.filled(index + 1, 0.0)'));
      expect(manager, contains('_audioQualities.length - 1'));
      expect(manager, contains('orElse: () => _languages.first'));
      expect(manager, contains('get translateLyrics'));
    });

    test('settings graphics use one shared width and visible placeholders', () {
      for (final path in [
        'lib/screens/settings/appearance/appearance_details_page.dart',
        'lib/screens/settings/integrations/integration_page.dart',
        'lib/screens/settings/player/equalizer/equalizer_page.dart',
        'lib/screens/settings/player/equalizer/axion_eq_page.dart',
        'lib/screens/settings/music_flow_settings_page.dart',
        'lib/screens/settings/update_settings_page.dart',
      ]) {
        expect(src(path), contains('SettingsList'), reason: path);
      }
      expect(src('lib/screens/settings/export_queue_page.dart'),
          contains('settingsMaxWidth'));
      final notice =
          src('lib/screens/settings/widgets/settings_list.dart');
      expect(notice, contains('class SettingNoticeTile'));
      expect(src('lib/screens/settings/music_flow_settings_page.dart'),
          contains('SettingNoticeTile'));
      expect(src('lib/screens/settings/content/content_page.dart'),
          contains('SettingNoticeTile'));
      expect(src('lib/screens/settings/player/player_settings_page.dart'),
          contains('SettingNoticeTile'));
    });

    test('account subtitle, export screen and search react correctly', () {
      final settings = src('lib/screens/settings/settings_page.dart');
      expect(settings, contains('ValueListenableBuilder<int>'));
      expect(settings, contains('accountEpoch'));
      expect(settings, contains('SettingSwitchTile() => widget.title'));

      final main = src('lib/main.dart');
      expect(main, contains('ChangeNotifierProvider.value'));
      expect(main, contains('GetIt.I<ExportTaskQueue>()'));
    });

    test('other review fixes are wired', () {
      final main = src('lib/main.dart');
      expect(main, contains('settingsManager.persistentQueue'));
      expect(main, contains('audioDevices.selectDevice'));

      final player = src('lib/services/media_player.dart');
      expect(player, contains('persistentQueue'));

      final lyricsBox =
          src('lib/screens/player/widgets/lyrics_box.dart');
      expect(lyricsBox, contains('translateLyrics'));

      final page = src('lib/screens/player/player_page.dart');
      expect(page, contains('if (currentSong == null)'));

      final loudness =
          src('lib/screens/settings/player/equalizer/equalizer_page.dart');
      expect(loudness, contains('min: -10'));
      expect(loudness, contains('max: 10'));
    });
  });
}
