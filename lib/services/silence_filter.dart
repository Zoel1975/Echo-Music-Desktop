import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'axion_eq_service.dart';

/// Builds the mpv lavfi audio-filter chain applied to the patched
/// just_audio_media_kit bridge: optional `silenceremove` (skip-silence),
/// an optional 10-band `equalizer`, and the `aeval` mix for separated stems.
class SilenceFilter {
  SilenceFilter._();

  static const String silence =
      'silenceremove=start_periods=1:start_duration=0.15:start_threshold=-60dB:'
      'stop_periods=-1:stop_duration=0.15:stop_threshold=-60dB';

  /// Pure: build ten separate mpv equalizer filters from gains.
  ///
  /// FFmpeg's `equalizer` filter handles one band per instance: bands must be
  /// comma-separated filters, not `|`-separated options.
  static String eqFilter(List<double> gains) {
    if (gains.length < 10) return '';
    return List<String>.generate(
      10,
      (i) =>
          'equalizer=f=${eqFrequencies[i].toInt()}:g=${gains[i].clamp(-12, 12)}',
    ).join(',');
  }

  /// Mix a four-channel stem file (drums, bass, other, vocals) to stereo,
  /// including only the enabled stems. Each kept stem is scaled by 1/N so
  /// solo and mute do not change the perceived loudness.
  static String stemPan(List<bool> enabled) {
    if (enabled.length != 4) return '';
    final indices = <int>[
      for (var i = 0; i < 4; i++)
        if (enabled[i]) i,
    ];
    if (indices.isEmpty) return 'aeval=0|0';
    final gain = (1.0 / indices.length).toStringAsFixed(4);
    final sum = indices.map((i) => '${gain}*val($i)').join('+');
    return 'aeval=$sum|$sum';
  }

  /// Pure: assemble the combined lavfi chain.
  /// Low-shelf cut used only on the outgoing player during a DJ blend.
  static const duck = 'bass=f=150:g=-8';

  static String buildChain({
    required bool skipSilence,
    List<double>? eqGains,
    bool eqEnabled = false,
    bool duckOutgoing = false,
    String? stemPanFilter,
  }) {
    final parts = <String>[];
    if (skipSilence) parts.add(silence);
    if (eqEnabled && eqGains != null && eqGains.length >= 10) {
      parts.add(eqFilter(eqGains));
    }
    if (duckOutgoing) parts.add(duck);
    if (stemPanFilter != null && stemPanFilter.isNotEmpty) {
      parts.add(stemPanFilter);
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
    bool duckOutgoing = false,
    String? stemPanFilter,
  }) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    JustAudioMediaKit.audioFilter = buildChain(
      skipSilence: enabled,
      eqGains: eqGains,
      eqEnabled: eqEnabled,
      duckOutgoing: duckOutgoing,
      stemPanFilter: stemPanFilter,
    );
  }

  static String? get current => JustAudioMediaKit.audioFilter;
}
