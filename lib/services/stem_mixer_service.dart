import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'eq_settings.dart';
import 'media_player.dart';
import 'settings_manager.dart';
import 'silence_filter.dart';

/// Four stem slots in the order used by the Demucs ONNX output and by the
/// four-channel cache file: drums, bass, other, vocals.
const List<String> stemNames = ['Drums', 'Bass', 'Other', 'Vocals'];

class StemMixState {
  const StemMixState({
    this.stemsLoaded = false,
    this.enabled = const [true, true, true, true],
  });

  final bool stemsLoaded;
  final List<bool> enabled;

  StemMixState copyWith({
    bool? stemsLoaded,
    List<bool>? enabled,
  }) =>
      StemMixState(
        stemsLoaded: stemsLoaded ?? this.stemsLoaded,
        enabled: enabled ?? this.enabled,
      );
}

/// Runtime stem mixer for separated four-channel files.
///
/// mpv plays one file with four channels and an `aeval` filter mixes only the
/// selected stems, sample-synchronized in a single player.
class StemMixerService extends ChangeNotifier {
  StemMixerService._();

  static final StemMixerService instance = StemMixerService._();

  StemMixState _state = const StemMixState();
  String? _stemPath;
  String? _stemVideoId;
  bool useStems = false;

  StemMixState get state => _state;
  String? get stemPath => _stemPath;
  String? get stemVideoId => _stemVideoId;
  bool hasStemsFor(String? videoId) =>
      videoId != null && _stemVideoId == videoId && _stemPath != null;
  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  String currentFilter(SettingsManager settings) => SilenceFilter.buildChain(
        skipSilence: settings.skipSilence,
        eqGains: EqSettings.savedGains(settings),
        eqEnabled: settings.equalizerEnabled,
        stemPanFilter:
            _state.stemsLoaded ? SilenceFilter.stemPan(_state.enabled) : null,
      );

  /// Called when the playing track changes: a cached stem file belongs to the
  /// previous video id and must not be applied to another song.
  void onTrackChanged(String? videoId) {
    if (_stemVideoId == null || _stemVideoId == videoId) return;
    _stemPath = null;
    _stemVideoId = null;
    useStems = false;
    _state = _state.copyWith(stemsLoaded: false);
    unawaited(apply());
    notifyListeners();
  }

  void setStemEnabled(int index, bool value) {
    if (index < 0 || index > 3 || _state.enabled[index] == value) return;
    final enabled = List<bool>.from(_state.enabled)..[index] = value;
    _state = _state.copyWith(enabled: enabled);
    unawaited(apply());
    notifyListeners();
  }

  void solo(int index) {
    if (index < 0 || index > 3) return;
    final enabled = List<bool>.filled(4, false)..[index] = true;
    _state = _state.copyWith(enabled: enabled);
    unawaited(apply());
    notifyListeners();
  }

  void restoreAll() {
    _state = _state.copyWith(enabled: const [true, true, true, true]);
    unawaited(apply());
    notifyListeners();
  }

  /// Attach a separated file for the current track. [path] is a four-channel
  /// WAV produced by the separation queue, or null when none exists.
  void setStemFile(String? path, String? videoId) {
    _stemPath = path;
    _stemVideoId = videoId;
    useStems = path != null;
    _state = _state.copyWith(stemsLoaded: path != null);
    unawaited(apply());
    notifyListeners();
  }

  bool _reloading = false;

  /// Apply the chain to future players and to the live main player.
  Future<void> apply() async {
    if (!GetIt.I.isRegistered<SettingsManager>()) return;
    final settings = GetIt.I<SettingsManager>();
    final filter = currentFilter(settings);
    EqSettings.apply(
      settings,
      stemPanFilter:
          _state.stemsLoaded ? SilenceFilter.stemPan(_state.enabled) : null,
    );
    if (_reloading ||
        !GetIt.I.isRegistered<MediaPlayer>() ||
        GetIt.I<MediaPlayer>().currentSongNotifier.value == null) {
      if (isDesktop) await JustAudioMediaKit.setMainPlayerAf(filter);
      return;
    }
    _reloading = true;
    try {
      // Reattach the stream first: mpv only picks up a new filter chain when
      // the audio stream starts.
      await GetIt.I<MediaPlayer>().reloadCurrentSource();
    } catch (_) {
    } finally {
      _reloading = false;
    }
    if (isDesktop) await JustAudioMediaKit.setMainPlayerAf(filter);
  }
}
