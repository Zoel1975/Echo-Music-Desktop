import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/silence_filter.dart';
import 'package:Echo/services/stem_mixer_service.dart';
import 'package:Echo/services/stem_separation_queue.dart';

void main() {
  test('stem aeval mixes only the enabled four channels', () {
    final drumsOnly = SilenceFilter.stemPan([true, false, false, false]);
    expect(drumsOnly, contains('1.0000*val(0)'));
    expect(drumsOnly, isNot(contains('*val(1)')));
    final all = SilenceFilter.stemPan([true, true, true, true]);
    expect(all, contains('0.2500*val(0)'));
    expect(all, contains('0.2500*val(3)'));
    expect(SilenceFilter.stemPan([false, false, false, false]),
        contains('aeval=0|0'));
    // The ineffective instant-vocal filter is gone.
    expect(SilenceFilter.buildChain(skipSilence: false), '');
  });

  test('mixer tracks the separated file and its video id', () {
    final mixer = StemMixerService.instance;
    mixer.setStemFile(r'C:\Music\Stems\abc.stems.wav', 'abc');
    expect(mixer.state.stemsLoaded, isTrue);
    expect(mixer.useStems, isTrue);
    expect(mixer.hasStemsFor('abc'), isTrue);
    expect(mixer.hasStemsFor('other'), isFalse);
    mixer.onTrackChanged('new');
    expect(mixer.state.stemsLoaded, isFalse);
    mixer.setStemFile(null, null);
    expect(mixer.state.stemsLoaded, isFalse);
  });

  test('separation queue uses the project model and safe cache names', () {
    expect(StemSeparationQueue.modelUrl, contains('htdemucs_fp16weights.onnx'));
    expect(StemSeparationQueue.modelUrl, contains('huggingface.co'));
    final path = StemSeparationQueue.instance.cachedPath('a/b?c');
    expect(path, endsWith('a_b_c.stems.wav'));
    final queue =
        File('lib/services/stem_separation_queue.dart').readAsStringSync();
    expect(queue, contains('StemPythonSetup.instance.ensure()'));
    expect(queue, contains('Process.start('));
    expect(queue, contains('PROGRESS'));
    expect(queue, isNot(contains('AudioSource.file')));
  });

  test('setup is automatic, progress is explicit and instant mute is gone', () {
    final queue =
        File('lib/services/stem_separation_queue.dart').readAsStringSync();
    expect(queue, contains('await prepare();'));
    expect(queue, contains('Future<void> startAll('));
    expect(queue, contains('allProgress'));
    expect(queue, contains('PROVIDER'));
    expect(queue, contains('Future<void>.delayed(const Duration(seconds: 4)'));
    expect(queue, contains('clearCompleted()'));
    final modal = File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modal, contains("'Download all & separate'"));
    expect(modal, contains('queue.startAll('));
    expect(modal, contains('FilterChip('));
    expect(modal, contains("'Enable all'"));
    expect(modal, isNot(contains("'Mute vocals (instant)'")));
    final page =
        File('lib/screens/player/player_page.dart').readAsStringSync();
    expect(page, contains('_StemArtworkControls'));
    expect(page, isNot(contains('mixer.toggleVocal')));
    final helper = File('tools/stems/separate.py').readAsStringSync();
    expect(helper, contains('DmlExecutionProvider'));
    expect(helper, contains('CUDAExecutionProvider'));
    expect(helper, contains('PROVIDER {used}'));
    expect(helper, contains('format="WAV"'));
  });
}
