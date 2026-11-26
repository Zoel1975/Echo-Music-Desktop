import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/beat_analysis.dart';

List<double> clickTrack({int sampleRate = 22050, int seconds = 12, double bpm = 120}) {
  final samples = List<double>.filled(sampleRate * seconds, 0.0);
  final period = 60.0 / bpm;
  for (var beat = 0; beat * period < seconds; beat++) {
    final start = (beat * period * sampleRate).round();
    final length = (0.06 * sampleRate).round();
    for (var i = 0; i < length && start + i < samples.length; i++) {
      final envelope = math.exp(-i / (sampleRate * 0.012));
      samples[start + i] =
          math.sin(2 * math.pi * 180 * i / sampleRate) * envelope * 0.9;
    }
  }
  return samples;
}

void main() {
  test('FFT rejects non-power-of-two sizes', () {
    expect(() => fft([1, 2, 3], [0, 0, 0]), throwsArgumentError);
  });

  test('detects the BPM of a synthetic beat track', () {
    final result = analyzePcm(clickTrack(), 22050);
    expect(result, isNotNull);
    expect(result!.bpm, closeTo(120, 6));
    expect(result.confidence, greaterThan(0));
    expect(result.firstBeatOffsetMs, greaterThanOrEqualTo(0));
  });

  test('short or silent audio has no beat grid', () {
    expect(analyzePcm(List<double>.filled(100, 0), 22050), isNull);
    expect(analyzePcm(List<double>.filled(22050 * 12, 0), 22050), isNull);
  });

  test('automix trigger keeps the fade end on a beat', () {
    const beat = BeatAnalysisResult(
      bpm: 120,
      firstBeatOffsetMs: 0,
      confidence: 1,
    );
    final trigger = automixTriggerMs(180000, 5000, beat);
    // Fade must still start before the natural (duration - crossfade) point.
    expect(trigger, greaterThanOrEqualTo(5000));
    expect(trigger, lessThanOrEqualTo(180000));
    final fadeEnd = 180000 - trigger + 5000;
    expect(fadeEnd % beat.beatPeriodMs, closeTo(0, 1));
  });

  test('energy scan finds mix-in and mix-out', () {
    final samples = clickTrack(seconds: 30);
    final mixIn = energyMixIn(samples, 22050);
    expect(mixIn, isNotNull);
    expect(mixIn!, greaterThanOrEqualTo(0));
    expect(mixIn, lessThanOrEqualTo(20000));

    // Tail starts at the energy of the bars; mix-out must be near the end.
    final tail = samples.sublist(samples.length - 22050 * 10);
    final mixOut = energyMixOut(tail, 22050, 30000);
    expect(mixOut, isNotNull);
    expect(mixOut!, greaterThan(30000 - 12000));
    expect(mixOut, lessThanOrEqualTo(30000));
  });

  test('incoming start is shifted so its beat lands at the fade end', () {
    const incoming = BeatAnalysisResult(
      bpm: 120, // 500 ms per beat
      firstBeatOffsetMs: 250,
      mixInMs: 0,
      confidence: 1,
    );
    const crossfadeMs = 5000;
    final start = beatAlignedStartMs(incoming, crossfadeMs);
    expect(start, greaterThanOrEqualTo(0));
    final phase = (start + crossfadeMs - incoming.firstBeatOffsetMs) %
        incoming.beatPeriodMs;
    expect(phase, closeTo(0, 1));
  });

  test('mix-out point moves the trigger earlier than the track end', () {
    const beat = BeatAnalysisResult(
      bpm: 120,
      firstBeatOffsetMs: 0,
      confidence: 1,
      mixOutMs: 170000,
    );
    final withMixOut = automixTriggerMs(180000, 5000, beat, mixOutMs: 170000);
    final natural = automixTriggerMs(180000, 5000, beat);
    expect(withMixOut, greaterThan(natural));
  });

  test('DJ blend is 16 beats clamped to a usable length', () {
    const slow = BeatAnalysisResult(
      bpm: 60,
      firstBeatOffsetMs: 0,
      confidence: 1,
    );
    const fast = BeatAnalysisResult(
      bpm: 180,
      firstBeatOffsetMs: 0,
      confidence: 1,
    );
    expect(djBlendDurationMs(slow), 15000); // 16 s -> capped
    expect(djBlendDurationMs(fast), 5333); // 16 * 333 ms
  });

  test('key detection returns a pitch class for a tonal signal', () {
    final rate = 22050;
    final samples = List<double>.filled(rate * 4, 0.0);
    for (var i = 0; i < samples.length; i++) {
      // A minor triad: A3, C4, E4.
      samples[i] = (math.sin(2 * math.pi * 220 * i / rate) +
              math.sin(2 * math.pi * 261.63 * i / rate) +
              math.sin(2 * math.pi * 329.63 * i / rate)) /
          3;
    }
    final key = estimateKey(samples, rate);
    expect(key, isNotNull);
    expect(key!.pitchClass, greaterThanOrEqualTo(0));
    expect(key.pitchClass, lessThanOrEqualTo(11));
  });

  test('JSON round-trip keeps the beat grid', () {
    const beat = BeatAnalysisResult(
      bpm: 128.5,
      firstBeatOffsetMs: 137.0,
      confidence: 0.8,
    );
    final restored = BeatAnalysisResult.fromJson(beat.toJson());
    expect(restored.bpm, 128.5);
    expect(restored.firstBeatOffsetMs, 137.0);
    expect(restored.confidence, 0.8);
  });
}
