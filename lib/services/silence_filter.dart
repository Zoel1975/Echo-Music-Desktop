import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// Builds mpv's lavfi `silenceremove` filter chain for desktop skip-silence,
/// and applies it to the patched just_audio_media_kit bridge.
///
/// mpv applies `af` to every player created after it is set, so toggling
/// skip-silence affects subsequently resolved tracks.
class SilenceFilter {
  SilenceFilter._();

  /// mpv audio filter: trim leading/trailing and long in-track silence.
  /// -60 dB threshold, min 0.15 s of silence before skipping, 0.05 s keep.
  static const String filter =
      'lavfi=[silenceremove=start_periods=1:start_duration=0.15:start_threshold=-60dB:'
      'stop_periods=-1:stop_duration=0.15:stop_threshold=-60dB]';

  static String buildFilter({required bool enabled}) => enabled ? filter : '';

  /// Apply (or clear) the filter at the media_kit bridge. On non-desktop
  /// platforms this is a no-op (Android/iOS use just_audio's native processor).
  static void apply({required bool enabled}) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    JustAudioMediaKit.audioFilter = buildFilter(enabled: enabled);
  }

  static String? get current => JustAudioMediaKit.audioFilter;
}
