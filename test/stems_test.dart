import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/silence_filter.dart';
import 'package:Echo/services/stem_mixer_service.dart';
import 'package:Echo/services/stem_separation_queue.dart';

void main() {
  test('instant vocal mute uses a center-channel pan filter', () {
    expect(SilenceFilter.vocalCancel, contains('c0=c0-0.98*c1'));
    expect(SilenceFilter.vocalCancel, contains('c1=c1-0.98*c0'));
    final chain = SilenceFilter.buildChain(
      skipSilence: false,
      vocalCancelEnabled: true,
    );
    expect(chain, contains('lavfi=['));
    expect(chain, contains(SilenceFilter.vocalCancel));
  });

  test('stem pan mixes only the enabled four channels', () {
    final drumsOnly = SilenceFilter.stemPan([true, false, false, false]);
    expect(drumsOnly, contains('1.0000*c0'));
    expect(drumsOnly, isNot(contains('*c1')));
    final all = SilenceFilter.stemPan([true, true, true, true]);
    expect(all, contains('0.2500*c0'));
    expect(all, contains('0.2500*c3'));
    expect(SilenceFilter.stemPan([false, false, false, false]),
        contains('c0=0|c1=0'));
  });

  test('mixer tracks the separated file and its video id', () {
    final mixer = StemMixerService.instance;
    mixer.setStemFile(r'C:\Music\Stems\abc.stems.wav', 'abc');
    expect(mixer.state.stemsLoaded, isTrue);
    expect(mixer.useStems, isTrue);
    expect(mixer.hasStemsFor('abc'), isTrue);
    expect(mixer.hasStemsFor('other'), isFalse);
    mixer.setStemFile(null, null);
    expect(mixer.state.stemsLoaded, isFalse);
    expect(mixer.hasStemsFor('abc'), isFalse);
  });

  test('separation queue uses the project model and safe cache names', () {
    expect(StemSeparationQueue.modelUrl, contains('htdemucs_fp16weights.onnx'));
    expect(StemSeparationQueue.modelUrl, contains('huggingface.co'));
    final path = StemSeparationQueue.instance.cachedPath('a/b?c');
    expect(path, endsWith('a_b_c.stems.wav'));
    final queue =
        File('lib/services/stem_separation_queue.dart').readAsStringSync();
    expect(queue, contains('Process.start(pythonExecutable'));
    expect(queue, contains('PROGRESS'));
    expect(queue, isNot(contains('AudioSource.file')));
  });

  test('the helper and player wiring are present', () {
    final player =
        File('lib/services/media_player.dart').readAsStringSync();
    expect(player, contains('mixer.hasStemsFor(videoId)'));
    expect(player, contains("format: 'Stems'"));
    final modal = File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modal, contains('showStemsSheet'));
    expect(modal, contains("title: 'Stems'"));
    final helper = File('tools/stems/separate.py').readAsStringSync();
    expect(helper, contains('PROGRESS'));
    expect(helper, contains('DONE'));
    expect(helper, contains('htdemucs'));
  });
}
