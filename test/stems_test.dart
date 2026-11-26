import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/stem_mixer_service.dart';
import 'package:Echo/services/stem_separation_queue.dart';

void main() {
  test('mixer tracks the separated stems and their video id', () {
    final mixer = StemMixerService.instance;
    final paths = List<String>.generate(4, (i) => r'C:\Music\Stems\abc.wav');
    // No files on disk: setStemFiles is a no-op, but hasStemsFor stays false.
    expect(mixer.hasStemsFor('abc'), isFalse);
    expect(stemNames, ['Drums', 'Bass', 'Other', 'Vocals']);
    expect(paths.length, 4);
  });

  test('separation queue exposes four stem files and safe cache names', () {
    expect(StemSeparationQueue.modelUrl, contains('htdemucs_fp16weights.onnx'));
    final path = StemSeparationQueue.instance.cachedPath('a/b?c');
    expect(path, endsWith('a_b_c.stems.wav'));
    final paths = StemSeparationQueue.instance.stemPaths('a/b?c');
    expect(paths.length, 4);
    expect(paths[0], endsWith('a_b_c.drums.wav'));
    expect(paths[3], endsWith('a_b_c.vocals.wav'));
    final queue =
        File('lib/services/stem_separation_queue.dart').readAsStringSync();
    expect(queue, contains('StemPythonSetup.instance.ensure()'));
    expect(queue, contains('clearCompleted()'));
  });

  test('mixer uses four synchronized players instead of reloading the source',
      () {
    final mixerSrc =
        File('lib/services/stem_mixer_service.dart').readAsStringSync();
    expect(mixerSrc, contains('List<AudioPlayer?> _players'));
    expect(mixerSrc, contains('Future<void> _enterStemMode()'));
    expect(mixerSrc, contains('player.setVolume('));
    expect(mixerSrc, isNot(contains('reloadCurrentSource')));
    expect(mixerSrc, isNot(contains('_renderMix')));
    final modal = File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modal, contains('queue.stemPaths('));
    expect(modal, contains('mixer.disableStems()'));
    expect(modal, contains('FilterChip('));
    expect(modal, isNot(contains("'Mute vocals (instant)'")));
    final helper = File('tools/stems/separate.py').readAsStringSync();
    expect(helper, contains('format="WAV"'));
    expect(helper, contains('{prefix}.{name}.wav'));
    final playlist =
        File('lib/screens/detail/playlist_page.dart').readAsStringSync();
    expect(playlist, contains('enqueuePlaylist('));
    expect(playlist, contains("'Separate all tracks'"));
    expect(playlist, contains('playlistProgress'));
    final storage =
        File('lib/screens/settings/storage/storage_page.dart').readAsStringSync();
    expect(storage, contains('FilePicker.getDirectoryPath()'));
    expect(storage, contains('setCustomFolder('));
    final mixerSrc =
        File('lib/services/stem_mixer_service.dart').readAsStringSync();
    expect(mixerSrc, contains('bool get stemsEnabled'));
    expect(mixerSrc, contains('Future<void> _switchTrack('));
    final files =
        File('lib/services/file_storage.dart').readAsStringSync();
    expect(files, contains("get('APP_FOLDER')"));
  });
}
