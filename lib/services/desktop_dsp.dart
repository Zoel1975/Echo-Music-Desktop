import 'dart:math' as math;

/// Pure desktop DSP: replay-gain normalization using the track's measured
/// loudness (InnerTube `loudnessDb`), mapped to a just_audio `setVolume` gain.
/// This is the cross-platform (incl. Windows) replacement for Android's
/// `AndroidLoudnessEnhancer`, which is a no-op on desktop.
class DesktopDsp {
  DesktopDsp._();

  /// Loudness preset → target integrated loudness (LUFS).
  static const presetTargets = {
    'Quiet': -20.0,
    'Normal': -16.0,
    'Loud': -13.0,
    'Aggressive': -10.0,
  };

  /// Compute the playback gain [0..1] for a track.
  ///
  /// - `userVolume`: the app's master volume (0..1).
  /// - `loudnessDb`: the track's measured loudness (LUFS), or null.
  /// - `normalizationOn`: whether replay gain is enabled.
  /// - `preset`: loudness preset name.
  /// - `targetGainDb`: additional manual gain in dB.
  static double playbackGain({
    required double userVolume,
    required double? loudnessDb,
    required bool normalizationOn,
    required String preset,
    double targetGainDb = 0.0,
  }) {
    var gain = userVolume.clamp(0.0, 1.0);
    if (normalizationOn && loudnessDb != null) {
      final target = presetTargets[preset] ?? presetTargets['Normal']!;
      // Replay gain: raise quiet tracks, lower loud ones, in the dB domain.
      final deltaDb = (target - loudnessDb) + targetGainDb;
      final gainDb = deltaDb.clamp(-12.0, 12.0);
      gain *= math.pow(10, gainDb / 20).toDouble();
    }
    return gain.clamp(0.0, 1.0);
  }

  /// Convert a user master volume + normalization into the gain the player
  /// should apply at track start. Alias kept explicit for call sites.
  static double forTrack({
    required double userVolume,
    required double? loudnessDb,
    required bool normalizationOn,
    required String preset,
    double targetGainDb = 0.0,
  }) =>
      playbackGain(
        userVolume: userVolume,
        loudnessDb: loudnessDb,
        normalizationOn: normalizationOn,
        preset: preset,
        targetGainDb: targetGainDb,
      );
}
