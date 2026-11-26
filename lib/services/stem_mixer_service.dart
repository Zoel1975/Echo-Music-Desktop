import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';

import 'eq_settings.dart';
import 'media_player.dart';
import 'settings_manager.dart';
import 'stem_separation_queue.dart';

/// Four stem slots in the order used by the Demucs ONNX output:
/// drums, bass, other, vocals.
const List<String> stemNames = ['Drums', 'Bass', 'Other', 'Vocals'];

class StemMixState {
  const StemMixState({
    this.stemsLoaded = false,
    this.enabled = const [true, true, true, true],
  });

  final bool stemsLoaded;
  final List<bool> enabled;

  StemMixState copyWith({bool? stemsLoaded, List<bool>? enabled}) => StemMixState(
        stemsLoaded: stemsLoaded ?? this.stemsLoaded,
        enabled: enabled ?? this.enabled,
      );
}

/// Real-time stem mixer.
///
/// Each stem is played by its own synchronized AudioPlayer. Toggling a stem
/// only changes that player's volume, so there is no file render, no source
/// reload and no audible gap.
class StemMixerService extends ChangeNotifier {
  StemMixerService._();

  static final StemMixerService instance = StemMixerService._();

  StemMixState _state = const StemMixState();
  List<String>? _stemPaths;
  String? _stemVideoId;
  final List<AudioPlayer?> _players = List<AudioPlayer?>.filled(4, null);
  Timer? _syncTimer;
  bool _switching = false;
  double _masterVolume = 1.0;
  bool _wasPlaying = false;
  Duration _position = Duration.zero;

  StemMixState get state => _state;
  bool get useStems => _state.stemsLoaded;
  List<String>? get stemPaths => _stemPaths;
  String? get stemVideoId => _stemVideoId;
  bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  String get currentFilter => '';

  List<Map<String, dynamic>> get debugPlayers => _players.map((p) => {
        'playing': p?.playing ?? false,
        'positionMs': p?.position.inMilliseconds ?? 0,
        'volume': p?.volume ?? 0.0,
      }).toList();

  bool get stemsEnabled {
    try {
      return GetIt.I.isRegistered<SettingsManager>() &&
          GetIt.I<SettingsManager>().extra<bool>('stemsEnabled', false);
    } catch (_) {
      return false;
    }
  }

  set stemsEnabled(bool value) {
    if (GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I<SettingsManager>().setExtra<bool>('stemsEnabled', value);
    }
  }

  bool hasStemsFor(String? videoId) =>
      videoId != null && _stemVideoId == videoId && _stemPaths != null;

  void onTrackChanged(String? videoId) {
    if (videoId == null || videoId.isEmpty) return;
    if (_stemVideoId == videoId) return;
    if (!stemsEnabled) {
      if (_state.stemsLoaded) unawaited(_exitStemMode(resumeMain: false));
      return;
    }
    unawaited(_switchTrack(videoId));
  }

  /// Automatically reuse the four stem players for the new track when stem
  /// mode is globally enabled and that track has been separated.
  Future<void> _switchTrack(String videoId) async {
    final paths = StemSeparationQueue.instance.stemPaths(videoId);
    if (paths.any((p) => !File(p).existsSync())) {
      _state = _state.copyWith(stemsLoaded: false);
      _stemPaths = null;
      _stemVideoId = videoId;
      await _exitStemMode(resumeMain: false);
      notifyListeners();
      return;
    }
    await _exitStemMode(resumeMain: false);
    _stemPaths = paths;
    _stemVideoId = videoId;
    _position = Duration.zero;
    _state = _state.copyWith(stemsLoaded: true);
    await _enterStemMode();
    notifyListeners();
  }

  void setStemEnabled(int index, bool value) {
    if (index < 0 || index > 3 || _state.enabled[index] == value) return;
    final enabled = List<bool>.from(_state.enabled)..[index] = value;
    _state = _state.copyWith(enabled: enabled);
    _updateVolumes();
    notifyListeners();
  }

  void solo(int index) {
    if (index < 0 || index > 3) return;
    final enabled = List<bool>.filled(4, false)..[index] = true;
    _state = _state.copyWith(enabled: enabled);
    _updateVolumes();
    notifyListeners();
  }

  void restoreAll() {
    _state = _state.copyWith(enabled: const [true, true, true, true]);
    _updateVolumes();
    notifyListeners();
  }

  /// Activate the separated stems for [videoId]. The paths are the four mono
  /// files written by the separator.
  Future<void> setStemFiles(String videoId, List<String> paths) async {
    if (paths.length != 4 || paths.any((p) => !File(p).existsSync())) return;
    stemsEnabled = true;
    _stemVideoId = videoId;
    _stemPaths = List<String>.from(paths);
    _state = _state.copyWith(stemsLoaded: true);
    notifyListeners();
    await _enterStemMode();
  }

  Future<void> disableStems() async {
    stemsEnabled = false;
    _state = _state.copyWith(stemsLoaded: false);
    _stemPaths = null;
    _stemVideoId = null;
    notifyListeners();
    await _exitStemMode(resumeMain: true);
  }

  void _updateVolumes() {
    for (var i = 0; i < 4; i++) {
      final player = _players[i];
      if (player == null) continue;
      final gain = _state.enabled[i] ? _masterVolume : 0.0;
      unawaited(player.setVolume(gain));
    }
  }

  Future<void> _enterStemMode() async {
    if (_switching || _players.every((p) => p != null)) return;
    _switching = true;
    final main = GetIt.I<MediaPlayer>();
    try {
      _position = main.player.position;
      _wasPlaying = main.player.playing;
      _masterVolume = main.player.volume;
      await main.player.pause();
      for (var i = 0; i < 4; i++) {
        final player = AudioPlayer();
        _players[i] = player;
        await player.setAudioSource(
          AudioSource.file(_stemPaths![i],
              tag: main.currentSongNotifier.value),
        );
        await player.seek(_position);
        await player.setVolume(_state.enabled[i] ? _masterVolume : 0.0);
      }
      for (final player in _players) {
        if (player != null && _wasPlaying) await player.play();
      }
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        final leader = _players.firstWhere((p) => p != null);
        final pos = leader!.position;
        for (final player in _players) {
          if (player != null &&
              (player.position - pos).inMilliseconds.abs() > 80) {
            unawaited(player.seek(pos));
          }
        }
      });
    } catch (e) {
      debugPrint('stem mode failed: $e');
      await _exitStemMode(resumeMain: true);
    } finally {
      _switching = false;
    }
  }

  Future<void> _exitStemMode({required bool resumeMain}) async {
    if (_switching) return;
    _syncTimer?.cancel();
    _syncTimer = null;
    final first = _players.firstWhere((p) => p != null, orElse: () => null);
    if (first != null) _position = first.position;
    for (var i = 0; i < 4; i++) {
      final player = _players[i];
      _players[i] = null;
      if (player == null) continue;
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
    if (resumeMain && GetIt.I.isRegistered<MediaPlayer>()) {
      final main = GetIt.I<MediaPlayer>().player;
      try {
        await main.seek(_position);
        if (_wasPlaying) await main.play();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    unawaited(_exitStemMode(resumeMain: false));
    super.dispose();
  }
}
