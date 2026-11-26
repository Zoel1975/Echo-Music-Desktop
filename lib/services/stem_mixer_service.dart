import 'dart:async';
import 'dart:io';
import 'dart:ui';

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
const List<String> stemShortNames = ['DRM', 'BAS', 'OTH', 'VOC'];
const List<String> stemKeys = ['D', 'B', 'I', 'V'];
const List<Color> stemColors = [
  Color(0xFFF59E0B), // Drums — amber
  Color(0xFFA855F7), // Bass — purple
  Color(0xFF14B8A6), // Other — teal
  Color(0xFFED5564), // Vocals — app seed colour
];

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
///
/// just_audio throws PlayerInterruptedException when two setAudioSource calls
/// overlap, so every enter/exit transition goes through [_enqueue]. This keeps
/// rapid track changes and batch-separation completions from leaking players
/// or leaving stale decoders running.
class StemMixerService extends ChangeNotifier {
  StemMixerService._();

  static final StemMixerService instance = StemMixerService._();

  StemMixState _state = const StemMixState();
  List<String>? _stemPaths;
  String? _stemVideoId;
  String? _pendingVideoId;
  final List<AudioPlayer?> _players = List<AudioPlayer?>.filled(4, null);
  Timer? _syncTimer;
  StreamSubscription<bool>? _mainGuard;
  Future<void> _transition = Future.value();
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

  bool get isPlaying => _players.any((p) => p?.playing ?? false);

  /// Play/pause all four stem players together. Used by the Space shortcut so
  /// it controls the audible source instead of the muted main player.
  Future<void> setPlaying(bool value) async {
    _wasPlaying = value;
    for (final player in _players) {
      if (player == null) continue;
      try {
        if (value) {
          await player.play();
        } else {
          await player.pause();
        }
      } catch (e) {
        debugPrint('stem playback toggle failed: $e');
      }
    }
  }

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

  /// Serialize every player transition. Errors are contained here so a failed
  /// switch can never surface as an uncaught async exception.
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _transition.then((_) async {
      try {
        await action();
      } catch (e, st) {
        debugPrint('stem transition failed: $e\n$st');
      }
    });
    _transition = next.catchError((Object _, StackTrace __) {});
    return next;
  }

  void onTrackChanged(String? videoId) {
    if (videoId == null || videoId.isEmpty) return;
    _pendingVideoId = videoId;
    if (_stemVideoId == videoId && _state.stemsLoaded) return;
    if (!stemsEnabled) {
      _pendingVideoId = null;
      unawaited(_exitStemMode(resumeMain: false));
      return;
    }
    unawaited(_switchTrack(videoId));
  }

  /// Automatically reuse the four stem players for the new track when stem
  /// mode is globally enabled and that track has been separated.
  Future<void> _switchTrack(String videoId) => _enqueue(() async {
        // A disable request can be queued behind a track change.
        if (!stemsEnabled) {
          await _exitPlayersOnly();
          _pendingVideoId = null;
          return;
        }
        // Use the latest requested track: rapid skips coalesce to the last one.
        final target = _pendingVideoId ?? videoId;
        final paths = StemSeparationQueue.instance.stemPaths(target);
        if (paths.any((p) => !File(p).existsSync())) {
          await _exitPlayersOnly();
          _stemPaths = null;
          _stemVideoId = target;
          _state = _state.copyWith(stemsLoaded: false);
          notifyListeners();
          return;
        }
        await _exitPlayersOnly();
        _stemPaths = paths;
        _stemVideoId = target;
        _position = Duration.zero;
        await _enterPlayers();
        notifyListeners();
      });

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
    applyPattern(const [true, true, true, true]);
  }

  /// Replace the whole enabled pattern at once (used by hold-to-mute keys).
  void applyPattern(List<bool> enabled) {
    if (enabled.length != 4) return;
    _state = _state.copyWith(enabled: List<bool>.from(enabled));
    _updateVolumes();
    notifyListeners();
  }

  /// Activate the separated stems for [videoId]. The paths are the four mono
  /// files written by the separator.
  Future<void> setStemFiles(String videoId, List<String> paths) async {
    if (paths.length != 4 || paths.any((p) => !File(p).existsSync())) return;
    stemsEnabled = true;
    _pendingVideoId = videoId;
    _stemVideoId = videoId;
    _stemPaths = List<String>.from(paths);
    _state = _state.copyWith(stemsLoaded: true);
    notifyListeners();
    await _enterStemMode();
  }

  /// Called when a background separation finishes. During a playlist batch
  /// many tracks complete in a row; only the one currently playing may take
  /// over the mixer, otherwise the audio would jump to a finished track.
  Future<void> activateIfCurrent(String videoId, List<String> paths) async {
    if (!stemsEnabled) return;
    if (!GetIt.I.isRegistered<MediaPlayer>()) return;
    final current = GetIt.I<MediaPlayer>().currentSongNotifier.value?.id;
    if (current == null || current != videoId) return;
    await setStemFiles(videoId, paths);
  }

  Future<void> disableStems() async {
    stemsEnabled = false;
    _state = _state.copyWith(stemsLoaded: false);
    _stemPaths = null;
    _stemVideoId = null;
    _pendingVideoId = null;
    notifyListeners();
    await _exitStemMode(resumeMain: true);
  }

  void _updateVolumes() {
    for (var i = 0; i < 4; i++) {
      final player = _players[i];
      if (player == null) continue;
      final gain = _state.enabled[i] ? _masterVolume : 0.0;
      unawaited(player.setVolume(gain).catchError((Object e, StackTrace st) {
        debugPrint('stem volume failed: $e');
      }));
    }
  }

  /// Create all four players in a local list and publish them only after every
  /// source loaded successfully. A failure therefore cannot leave half of the
  /// slots pointing at disposed players.
  Future<void> _enterPlayers() async {
    final paths = _stemPaths;
    if (paths == null || paths.length != 4) return;
    if (_players.any((p) => p != null)) await _exitPlayersOnly();
    if (!GetIt.I.isRegistered<MediaPlayer>()) return;
    final main = GetIt.I<MediaPlayer>();
    final position = main.player.position;
    final wasPlaying = main.player.playing;
    final master = main.player.volume;
    await main.player.pause();
    final created = <AudioPlayer>[];
    try {
      for (var i = 0; i < 4; i++) {
        final player = AudioPlayer();
        created.add(player);
        await player.setAudioSource(
          AudioSource.file(paths[i], tag: main.currentSongNotifier.value),
        );
        await player.seek(position);
        await player.setVolume(_state.enabled[i] ? master : 0.0);
      }
      if (wasPlaying) {
        for (final player in created) {
          await player.play();
        }
      }
      for (var i = 0; i < 4; i++) {
        _players[i] = created[i];
      }
      _position = position;
      _wasPlaying = wasPlaying;
      _masterVolume = master;
      _state = _state.copyWith(stemsLoaded: true);
      await _installMainGuard(main.player);
      _startSyncTimer();
    } catch (e) {
      debugPrint('stem mode failed: $e');
      for (final player in created) {
        try {
          await player.stop();
        } catch (_) {}
        try {
          await player.dispose();
        } catch (_) {}
      }
      _state = _state.copyWith(stemsLoaded: false);
      try {
        await main.player.seek(position);
        if (wasPlaying) await main.player.play();
      } catch (_) {}
    }
  }

  Future<void> _enterStemMode() => _enqueue(_enterPlayers);

  /// MediaPlayer starts the main track again on several async paths (queue
  /// restore, crossfade, playAll). Keep a single listener that pauses it for
  /// the whole time stem mode is active, so the two are never audible at once.
  Future<void> _installMainGuard(AudioPlayer main) async {
    await _mainGuard?.cancel();
    _mainGuard = main.playingStream.listen((playing) {
      if (playing && _state.stemsLoaded) {
        debugPrint('[stems] main player resumed during stem mode; pausing it');
        unawaited(main.pause().catchError((Object e, StackTrace st) {}));
      }
    });
  }

  Future<void> _exitPlayersOnly() async {
    await _mainGuard?.cancel();
    _mainGuard = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    final first = _players.firstWhere((p) => p != null, orElse: () => null);
    if (first != null) {
      try {
        _position = first.position;
      } catch (_) {}
    }
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
  }

  Future<void> _exitStemMode({required bool resumeMain}) => _enqueue(() async {
        await _exitPlayersOnly();
        if (resumeMain && GetIt.I.isRegistered<MediaPlayer>()) {
          final main = GetIt.I<MediaPlayer>().player;
          try {
            await main.seek(_position);
            if (_wasPlaying) await main.play();
          } catch (_) {}
        }
      });

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // The timer can fire while a track change is disposing the players.
      final leader = _players.firstWhere((p) => p != null, orElse: () => null);
      final pos = leader?.position;
      if (pos == null) return;
      for (final player in _players) {
        if (player != null &&
            (player.position - pos).inMilliseconds.abs() > 80) {
          unawaited(player.seek(pos).catchError((Object e, StackTrace st) {}));
        }
      }
    });
  }

  @override
  void dispose() {
    _mainGuard?.cancel();
    _mainGuard = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    unawaited(_exitStemMode(resumeMain: false));
    super.dispose();
  }
}
