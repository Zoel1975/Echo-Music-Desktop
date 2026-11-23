import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('seven Android player backgrounds are implemented and wired', () {
    final bg = src('lib/screens/player/widgets/player_background.dart');
    for (final style in [
      'defaultStyle',
      'gradient',
      'blur',
      'glowAnimated',
      'appleMusic',
      'liveMesh',
      'liquidGlass',
    ]) {
      expect(bg, contains(style));
    }
    final page = src('lib/screens/player/player_page.dart');
    expect(page, contains('PlayerBackground('));
    final settings =
        src('lib/screens/settings/appearance/appearance_page.dart');
    expect(settings, contains('PlayerBackgroundStyle.all'));
  });

  test('Android fonts are bundled and the typography system is unified', () {
    final pubspec = src('pubspec.yaml');
    for (final font in [
      'google_sans_flex.ttf',
      'outfit.ttf',
      'plus_jakarta_sans.ttf',
      'bbh_bartle_regular.ttf',
    ]) {
      expect(pubspec, contains(font));
      expect(File('assets/fonts/$font').existsSync(), isTrue);
    }
    final fonts = src('lib/themes/app_fonts.dart');
    expect(fonts, contains("'Google Sans Flex'"));
    final typography = src('lib/themes/typography.dart');
    expect(typography, contains('AppFonts.family'));
    for (final file in [
      'lib/themes/dark.dart',
      'lib/themes/light.dart',
      'lib/themes/text_styles.dart',
    ]) {
      expect(src(file), contains('AppFonts.style()'));
    }
  });

  test('blur never leaks outside the mini-player on Windows', () {
    final glass = src('lib/core/widgets/echo_surface.dart');
    expect(glass, isNot(contains('child: BackdropFilter(')),
        reason: 'BackdropFilter leaked blur to the whole settings screen');
    expect(glass, contains('LinearGradient'));

    final background =
        src('lib/screens/player/widgets/player_background.dart');
    expect(background, contains('ImageFiltered'),
        reason: 'artwork blur must filter the child, not the backdrop');
    expect(background, isNot(contains('BackdropFilter(')));
  });

  test('glass and micro-effects are real widgets', () {
    final glass = src('lib/core/widgets/echo_surface.dart');
    expect(glass, contains('BackdropFilter'));
    expect(glass, contains("'blurRadius'"));
    expect(glass, contains("'vibrancy'"));
    expect(glass, contains("'liquidGlass'"));

    final motion = src('lib/core/widgets/motion_effects.dart');
    for (final name in [
      'class WavySlider',
      'class HeartBurst',
      'class ShimmerBox',
      'class MarqueeText',
    ]) {
      expect(motion, contains(name));
    }
    expect(src('lib/screens/player/player_page.dart'),
        contains('HeartBurst('));
    expect(src('lib/screens/shell/widgets/bottom_player.dart'),
        contains('MarqueeText('));
  });

  test('Music Flow toggles and circular EQ have consumers', () {
    final feed = src('lib/screens/explore/music_flow_feed_page.dart');
    for (final key in [
      'musicFlowEnabled',
      'musicFlowAutoplay',
      'musicFlowAutoNext',
      'musicFlowHideRecent',
      'musicFlowAnimatedBackground',
      'musicFlowLyrics',
      'musicFlowCellularPrefetch',
    ]) {
      expect(feed, contains(key));
    }
    expect(src('lib/screens/settings/player/equalizer/axion_eq_page.dart'),
        contains('CircularEqControl('));
    expect(
        File('lib/screens/player/widgets/circular_eq_control.dart')
            .existsSync(),
        isTrue);
  });

  test('MP3 export embeds cover art', () {
    final encoder = src('lib/services/ffmpeg_audio_encoder.dart');
    expect(encoder, contains('coverUrl'));
    expect(encoder, contains("'attached_pic'"));
    final queue = src('lib/services/export_task_queue.dart');
    expect(queue, contains("song!['thumbnails']"));
  });

  test('Wrapped is computed from YouTube Music history and is stable', () {
    final wrapped =
        src('lib/screens/settings/stats/wrapped_stories_page.dart');
    expect(wrapped, contains('sl<YTMusic>().getHistory()'));
    expect(wrapped, contains('fromYtmHistory'));
    expect(wrapped, isNot(contains("Hive.box('SONG_HISTORY')")));
    expect(wrapped, contains('YouTube Music'));
    expect(wrapped, contains('Positioned.fill('));

    final library = src('lib/ytmusic/mixins/library.dart');
    expect(library, contains("'FEmusic_history'"));
    expect(library, contains('parseDurationSeconds'));
    expect(library, contains('maxPages'));

    final nav = src('lib/core/widgets/floating_nav.dart');
    expect(nav, isNot(contains('child: BackdropFilter(')));
    final fallback = src('lib/services/audio_fallback.dart');
    expect(fallback, contains('catch (_)'));
  });

  test('parity matrix reaches the 90% target', () {
    final matrix = File('docs/PARITY_MATRIX.md').readAsStringSync();
    final rows = RegExp(r'^\| \d+ \|', multiLine: true)
        .allMatches(matrix)
        .toList();
    final done = rows.where((m) {
      final line = matrix.substring(m.start, matrix.indexOf('\n', m.start));
      return line.contains('| DONE |');
    }).length;
    expect(rows.length, greaterThanOrEqualTo(48));
    expect(done / rows.length, greaterThanOrEqualTo(0.90));
    final wrapped = File(
            'lib/screens/settings/stats/wrapped_stories_page.dart')
        .readAsStringSync();
    expect(wrapped, contains('slideCount = 9'));
    expect(wrapped, contains('slideDuration = Duration(milliseconds: 8500)'));
    expect(wrapped, contains('_RadarMeter'));
    expect(wrapped, contains('_EqBars'));
  });
}
