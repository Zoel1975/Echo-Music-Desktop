import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'axion_eq_service.dart';

/// Builds the mpv lavfi audio-filter chain applied to the patched
/// just_audio_media_kit bridge: optional `silenceremove` (skip-silence) plus
/// an optional 10-band `equalizer` (AXION / AutoEq). mpv applies `af` to every
/// player created after it is set.
class SilenceFilter {
  SilenceFilter._();

  static const String silence =
      'silenceremove=start_periods=1:start_duration=0.15:start_threshold=-60dB:'
      'stop_periods=-1:stop_duration=0.15:stop_threshold=-60dB';

  /// Pure: build a 10-band mpv equalizer filter from gains (Hz -> f= freq).
  static String eqFilter(List<double> gains) {
    if (gains.length < 10) return '';
    final parts = <String>[];
    for (var i = 0; i < 10; i++) {
      parts.add('f=${eqFrequencies[i].toInt()}:g=${gains[i].clamp(-12, 12)}');
    }
    return 'equalizer=${parts.join('|')}';
  }

  /// Pure: assemble the combined lavfi chain.
  static String buildChain({
    required bool skipSilence,
    List<double>? eqGains,
    bool eqEnabled = false,
  }) {
    final parts = <String>[];
    if (skipSilence) parts.add(silence);
    if (eqEnabled && eqGains != null && eqGains.length >= 10) {
      parts.add(eqFilter(eqGains));
    }
    if (parts.isEmpty) return '';
    return 'lavfi=[${parts.join(',')}]';
  }

  static String buildFilter({required bool enabled}) =>
      buildChain(skipSilence: enabled);

  /// Apply the combined chain at the media_kit bridge. No-op on mobile.
  static void apply({
    required bool enabled,
    List<double>? eqGains,
    bool eqEnabled = false,
  }) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    JustAudioMediaKit.audioFilter = buildChain(
      skipSilence: enabled,
      eqGains: eqGains,
      eqEnabled: eqEnabled,
    );
  }

  static String? get current => JustAudioMediaKit.audioFilter;
}
