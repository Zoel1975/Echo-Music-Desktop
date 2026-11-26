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
    expect(modal, contains('EchoSurface('));
    expect(modal, contains('GridView.count'));
    expect(modal, contains('BottomModalLayout('));
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
    final mixerGlobal =
        File('lib/services/stem_mixer_service.dart').readAsStringSync();
    expect(mixerGlobal, contains('bool get stemsEnabled'));
    expect(mixerGlobal, contains('Future<void> _switchTrack('));
    expect(mixerGlobal, contains('void applyPattern('));
    final keys = File('lib/services/keyboard_shortcuts.dart').readAsStringSync();
    expect(keys, contains('LogicalKeyboardKey.space'));
    expect(keys, contains('LogicalKeyboardKey.arrowRight'));
    expect(keys, contains('LogicalKeyboardKey.keyV'));
    expect(keys, contains('Duration(milliseconds: 250)'));
    final files =
        File('lib/services/file_storage.dart').readAsStringSync();
    expect(files, contains("get('APP_FOLDER')"));
  });

  test('stem transitions are serialized and stale temp files are cleaned', () {
    final mixer =
        File('lib/services/stem_mixer_service.dart').readAsStringSync();
    expect(mixer, contains('Future<void> _enqueue('));
    expect(mixer, contains('Future<void> _enterPlayers()'));
    expect(mixer, contains('Future<void> _exitPlayersOnly()'));
    expect(mixer, contains('orElse: () => null'));
    expect(mixer, contains('catchError'));
    expect(mixer, contains('Future<void> activateIfCurrent('));

    final queue =
        File('lib/services/stem_separation_queue.dart').readAsStringSync();
    expect(queue, contains('_cleanupStaleTemps()'));
    expect(queue, contains('Duration(hours: 12)'));
    expect(queue, contains("'.decode.wav'"));
    expect(queue, contains("'.part'"));
    expect(queue, contains('stemPaths(videoId).every'));
    expect(queue, contains('_playlistErrors'));
    expect(queue, contains('playlistSeparated'));
    expect(queue, contains('Duration(milliseconds: 200)'));
    expect(queue, contains('lastDownloadError'));
    expect(queue, contains('ahead <= index + 3'));
    final page =
        File('lib/screens/detail/playlist_page.dart').readAsStringSync();
    expect(page, contains('Separazione già in corso'));
    expect(page, contains('Nessun brano nella playlist'));
    expect(page, contains('playlistErrors'));

    final keys =
        File('lib/services/keyboard_shortcuts.dart').readAsStringSync();
    expect(keys, contains('KeyRepeatEvent'));
    expect(keys, contains('void _safe('));
    expect(keys, contains('LogicalKeyboardKey.keyD'));
    expect(keys, contains('LogicalKeyboardKey.keyB'));
    expect(keys, contains('LogicalKeyboardKey.keyI'));
    expect(keys, contains('stemHoldKeys'));
    expect(keys, contains('mixer.setPlaying('));
    expect(mixer, contains('StreamSubscription<bool>? _mainGuard'));
    expect(mixer, contains('Future<void> _installMainGuard('));
    expect(mixer, contains('bool get isPlaying'));
    expect(mixer, contains('Future<void> setPlaying(bool value)'));

    expect(mixer, contains('List<Color> stemColors'));
    expect(mixer, contains('const List<String> stemKeys'));
    final player =
        File('lib/screens/player/player_page.dart').readAsStringSync();
    expect(player, contains('_stemChip('));
    expect(player, contains('stemShortNames[i]'));
    expect(player, contains('Tooltip('));
    final modalSrc =
        File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modalSrc, contains('stemKeys[i]'));
    expect(modalSrc, contains('stemColors[i]'));

    expect(queue, contains('void _notify('));
    expect(queue, contains('BottomMessage.showOn('));
    expect(player, contains('mixer.setPlaying(!mixer.isPlaying)'));
    final mini = File('lib/screens/shell/widgets/bottom_player.dart')
        .readAsStringSync();
    expect(mini, contains('StemMixerService.instance'));
    expect(mini, contains('.setPlaying(!mixer.isPlaying)'));

    expect(mixer, contains('ValueNotifier<Duration> positionNotifier'));
    expect(mixer, contains('void _startPositionTimer()'));
    expect(mixer, contains('Future<void> seek(Duration position)'));
    expect(mixer, contains('Future<void> seekBy(Duration delta)'));
    expect(player, contains('StemMixerService.instance.positionNotifier'));
    expect(player, contains('mixer.seek(position)'));
    expect(player, contains('mixer.seekBy('));
  });
}
