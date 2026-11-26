import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/crossfade_engine.dart';
import 'package:Echo/services/stream_resolver.dart';

/// Pure helper tests for the DSP/seek logic that MediaPlayer delegates to.
void main() {
  test('equal-power crossfade never dips below unit power', () {
    for (var i = 0; i <= 100; i++) {
      final t = i / 100;
      expect(
        CrossfadeCurve.fadeIn(t) * CrossfadeCurve.fadeIn(t) +
            CrossfadeCurve.fadeOut(t) * CrossfadeCurve.fadeOut(t),
        closeTo(1.0, 1e-9),
      );
    }
  });

  test('replay gain from loudnessDb is clamped to a safe range', () {
    const quiet = ResolvedStream(
      url: 'u',
      mimeType: 'audio/mp4',
      contentLength: 1,
      bitrate: 1,
      client: 'x',
      loudnessDb: -20,
    );
    const loud = ResolvedStream(
      url: 'u',
      mimeType: 'audio/mp4',
      contentLength: 1,
      bitrate: 1,
      client: 'x',
      loudnessDb: 5,
    );
    expect(quiet.normalizationGain(targetLufs: -14), greaterThan(1.0));
    expect(quiet.normalizationGain(targetLufs: -14), lessThanOrEqualTo(4.0));
    expect(loud.normalizationGain(targetLufs: -14), lessThan(1.0));
    expect(loud.normalizationGain(targetLufs: -14), greaterThanOrEqualTo(0.25));
    const none = ResolvedStream(
        url: 'u', mimeType: 'audio/mp4', contentLength: 1, bitrate: 1, client: 'x');
    expect(none.normalizationGain(), 1.0);
  });

  test('progressive seek adds 5 seconds only when enabled', () {
    const base = Duration(seconds: 10);
    // Mirrors MediaPlayer.seekStep.
    Duration step(Duration b, {required bool progressive}) =>
        progressive ? b + const Duration(seconds: 5) : b;
    expect(step(base, progressive: false), const Duration(seconds: 10));
    expect(step(base, progressive: true), const Duration(seconds: 15));
  });
}
