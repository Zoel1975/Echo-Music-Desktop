import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'eq_settings.dart';
import 'settings_manager.dart';
import 'silence_filter.dart';

/// Four stem slots in the order used by the Demucs ONNX output and by the
/// four-channel cache file: drums, bass, other, vocals.
const List<String> stemNames = ['Drums', 'Bass', 'Other', 'Vocals'];

class StemMixState {
  const StemMixState({
    this.vocalMuted = false,
    this.stemsLoaded = false,
    this.enabled = const [true, true, true, true],
  });

  final bool vocalMuted;
  final bool stemsLoaded;
  final List<bool> enabled;

  StemMixState copyWith({
    bool? vocalMuted,
    bool? stemsLoaded,
    List<bool>? enabled,
  }) =>
      StemMixState(
        vocalMuted: vocalMuted ?? this.vocalMuted,
        stemsLoaded: stemsLoaded ?? this.stemsLoaded,
        enabled: enabled ?? this.enabled,
      );
}

/// Runtime stem mixer.
///
/// Fast mode uses a center-channel cancellation filter on the live stereo
/// stream, so muting vocals is instant and needs no model. When a separated
/// four-channel file is available, the same mpv filter chain uses `pan` to mix
/// only the selected stems, sample-synchronized in a single player.
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

  /// The filter applied to the main player right now.
  String currentFilter(SettingsManager settings) => SilenceFilter.buildChain(
        skipSilence: settings.skipSilence,
        eqGains: EqSettings.savedGains(settings),
        eqEnabled: settings.equalizerEnabled,
        vocalCancelEnabled: _state.vocalMuted && !_state.stemsLoaded,
        stemPanFilter:
            _state.stemsLoaded ? SilenceFilter.stemPan(_state.enabled) : null,
      );

  void toggleVocal() => setVocalMuted(!_state.vocalMuted);

  void setVocalMuted(bool value) {
    if (_state.vocalMuted == value) return;
    _state = _state.copyWith(vocalMuted: value);
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
    _state = _state.copyWith(
      enabled: const [true, true, true, true],
      vocalMuted: false,
    );
    unawaited(apply());
    notifyListeners();
  }

  /// Attach a separated file for the current track. [path] is a four-channel
  /// WAV/FLAC produced by the separation queue, or null when none exists.
  void setStemFile(String? path, String? videoId) {
    _stemPath = path;
    _stemVideoId = videoId;
    useStems = path != null;
    _state = _state.copyWith(stemsLoaded: path != null);
    unawaited(apply());
    notifyListeners();
  }

  /// Apply the chain both to future players (bridge default) and to the live
  /// main player (mpv property) so the change is audible immediately.
  Future<void> apply() async {
    if (!GetIt.I.isRegistered<SettingsManager>()) return;
    final settings = GetIt.I<SettingsManager>();
    final filter = currentFilter(settings);
    EqSettings.apply(
      settings,
      vocalCancelEnabled: _state.vocalMuted && !_state.stemsLoaded,
      stemPanFilter:
          _state.stemsLoaded ? SilenceFilter.stemPan(_state.enabled) : null,
    );
    if (isDesktop) {
      await JustAudioMediaKit.setMainPlayerAf(filter);
    }
  }
}
