import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('harmonic mixing is wired from settings to the transition', () {
    final settings = src('lib/services/settings_manager.dart');
    expect(settings, contains('automixHarmonicMix'));
    expect(settings, contains('AUTOMIX_HARMONIC_MIX'));

    final cubit =
        src('lib/screens/settings/player/cubit/player_settings_cubit.dart');
    expect(cubit, contains('setAutomixHarmonicMix'));

    final state =
        src('lib/screens/settings/player/cubit/player_settings_state.dart');
    expect(state, contains('automixHarmonicMix'));

    final page = src('lib/screens/settings/player/player_settings_page.dart');
    expect(page, contains("'Automix · mixing armonico'"));

    final player = src('lib/services/media_player.dart');
    expect(player, contains('harmonic_mixing.dart'));
    expect(player, contains('camelotFor(_beat!)'));
    expect(player, contains('pickHarmonicNext('));
    expect(player, contains('moveAudioSource(chosen, nextIdx)'));
    expect(player, contains('await _applyHarmonicMix(idx, nextIdx)'));

    final debug = src('lib/services/automix_debug.dart');
    expect(debug, contains('harmonicChoice'));
    expect(debug, contains('harmonicScore'));

    final debugPage =
        src('lib/screens/settings/player/automix_debug_page.dart');
    expect(debugPage, contains("'ARMONIA:"));
  });
}
