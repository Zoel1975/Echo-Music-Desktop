import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('automix beat-align is wired from settings to the crossfade trigger',
      () {
    final settings = src('lib/services/settings_manager.dart');
    expect(settings, contains('automixBeatAlign'));
    expect(settings, contains('AUTOMIX_BEAT_ALIGN'));

    final state =
        src('lib/screens/settings/player/cubit/player_settings_state.dart');
    expect(state, contains('automixBeatAlign'));

    final cubit =
        src('lib/screens/settings/player/cubit/player_settings_cubit.dart');
    expect(cubit, contains('setAutomixBeatAlign'));

    final page = src('lib/screens/settings/player/player_settings_page.dart');
    expect(page, contains('S.of(context).AutomixAllineaAlBeat'));

    final player = src('lib/services/media_player.dart');
    expect(player, contains('BeatAnalyzerService.analyzeSong'));
    expect(player, contains('automixTriggerMs('));
    expect(player, contains('beatAlignedStartMs('));
    expect(player, contains('mixOutMs: _beat!.mixOutMs'));
    expect(player, contains('_maybeAnalyzeNextBeat(nextIdx)'));
    expect(player, contains('djBlendDurationMs('));
    expect(player, contains('_createDuckedOutPlayer()'));
    expect(player, contains('EqSettings.apply(settings, duckOutgoing: true)'));

    final silence =
        File('lib/services/silence_filter.dart').readAsStringSync();
    expect(silence, contains("bass=f=150:g=-8"));
    expect(silence, contains('duckOutgoing'));
    expect(player, contains('settings.automixBeatAlign'));

    final main = src('lib/main.dart');
    expect(main, contains("Hive.openBox('BEAT_ANALYSIS')"));

    final analyzer = src('lib/services/beat_analyzer_service.dart');
    expect(analyzer, contains('FFmpegKit.executeWithArguments'));
    expect(analyzer, contains("Hive.box(_boxName).put"));

    final doc = src('docs/AUTOMIX.md');
    expect(doc, contains('DJ blend'));
  });

  test('the incoming track is ready before the fade-in starts', () {
    final player = src('lib/services/media_player.dart');
    expect(player, contains('Future<void> _waitForIncomingReady('));
    expect(player, contains('bufferedPosition'));

    // Both the automatic queue transition and the manual switch must wait
    // before ramping the incoming volume up, otherwise the fresh stream is
    // silent for the first moments of the fade (audible as a stutter).
    final trigger = player.substring(
      player.indexOf('Future<void> _triggerQueueCrossfade('),
      player.indexOf('/// Android SponsorBlock'),
    );
    expect(trigger, contains('await _player.play()'));
    // The standby plays the same track as the main player: re-sync it before
    // the handoff so the two copies are not phase-offset (audible stutter).
    expect(trigger, contains('standby risincronizzato'));
    expect(trigger, contains('await outPlayer.seek(mainPos)'));
    final fadeAt = trigger.indexOf('await _xfade!.start(');
    final waitAt = trigger.indexOf('await _waitForIncomingReady(');
    expect(waitAt, greaterThan(0));
    expect(waitAt, lessThan(fadeAt));

    final manual = player.substring(
      player.indexOf('Future<void> _crossfadeTo('),
      player.indexOf('/// Re-attach the current audio source'),
    );
    expect(manual.indexOf('await _waitForIncomingReady('),
        lessThan(manual.indexOf('await _xfade!.start(')));
  });
}
