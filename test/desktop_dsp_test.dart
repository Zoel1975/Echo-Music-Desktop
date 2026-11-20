import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/desktop_dsp.dart';
import 'package:Echo/services/queue_crossfade.dart';

void main() {
  group('DesktopDsp (Windows replay-gain normalization)', () {
    test('normalization raises quiet tracks and lowers loud ones', () {
      final quiet = DesktopDsp.forTrack(
        userVolume: 1.0,
        loudnessDb: -24,
        normalizationOn: true,
        preset: 'Normal',
      );
      final loud = DesktopDsp.forTrack(
        userVolume: 1.0,
        loudnessDb: -8,
        normalizationOn: true,
        preset: 'Normal',
      );
      expect(quiet, greaterThan(loud));
      expect(quiet, lessThanOrEqualTo(1.0));
    });

    test('disabled normalization leaves user volume unchanged', () {
      final g = DesktopDsp.forTrack(
        userVolume: 0.7,
        loudnessDb: -14,
        normalizationOn: false,
        preset: 'Normal',
      );
      expect(g, closeTo(0.7, 1e-9));
    });

    test('no loudness metadata falls back to user volume', () {
      final g = DesktopDsp.forTrack(
        userVolume: 0.6,
        loudnessDb: null,
        normalizationOn: true,
        preset: 'Loud',
      );
      expect(g, closeTo(0.6, 1e-9));
    });

    test('gain is always clamped to 0..1', () {
      for (final db in [-60.0, -30.0, 0.0, 30.0]) {
        final g = DesktopDsp.forTrack(
          userVolume: 1.0,
          loudnessDb: db,
          normalizationOn: true,
          preset: 'Aggressive',
        );
        expect(g, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('QueueEndCrossfade (automatic advance pre-arm)', () {
    test('arms only within the crossfade window when a next track exists', () {
      final arm = QueueEndCrossfade.evaluate(
        position: const Duration(seconds: 55),
        duration: const Duration(seconds: 60),
        crossfade: const Duration(seconds: 5),
        enabled: true,
        hasNext: true,
        alreadyArmed: false,
      );
      expect(arm.shouldArm, isTrue);
      expect(arm.remaining, const Duration(seconds: 5));

      final tooEarly = QueueEndCrossfade.evaluate(
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
        crossfade: const Duration(seconds: 5),
        enabled: true,
        hasNext: true,
        alreadyArmed: false,
      );
      expect(tooEarly.shouldArm, isFalse);
    });

    test('does not arm when disabled, no next, or already armed', () {
      expect(
        QueueEndCrossfade.evaluate(
          position: const Duration(seconds: 58),
          duration: const Duration(seconds: 60),
          crossfade: const Duration(seconds: 5),
          enabled: false,
          hasNext: true,
          alreadyArmed: false,
        ).shouldArm,
        isFalse,
      );
      expect(
        QueueEndCrossfade.evaluate(
          position: const Duration(seconds: 58),
          duration: const Duration(seconds: 60),
          crossfade: const Duration(seconds: 5),
          enabled: true,
          hasNext: false,
          alreadyArmed: false,
        ).shouldArm,
        isFalse,
      );
      expect(
        QueueEndCrossfade.evaluate(
          position: const Duration(seconds: 58),
          duration: const Duration(seconds: 60),
          crossfade: const Duration(seconds: 5),
          enabled: true,
          hasNext: true,
          alreadyArmed: true,
        ).shouldArm,
        isFalse,
      );
    });
  });
}
