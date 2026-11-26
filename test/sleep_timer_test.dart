import 'dart:async';

import 'package:Echo/services/sleep_timer.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTarget implements SleepTimerTarget {
  @override
  double volume = 1.0;

  bool paused = false;
  final List<double> volumeTrace = [];

  @override
  Future<void> pause() async {
    paused = true;
  }
}

void main() {
  group('SleepTimer', () {
    test('is inactive by default', () {
      final timer = SleepTimer(_FakeTarget());
      expect(timer.isActive, isFalse);
      expect(timer.remaining.value, isNull);
      expect(timer.pauseWhenSongEnd, isFalse);
    });

    test('fades out, pauses and restores volume when the timer expires', () async {
      final target = _FakeTarget();
      final timer = SleepTimer(
        target,
        fadeDuration: const Duration(milliseconds: 30),
        fadeSteps: 3,
      );

      timer.start(const Duration(milliseconds: 20));
      expect(timer.isActive, isTrue);
      expect(timer.remaining.value, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(target.paused, isTrue);
      expect(target.volume, 1.0, reason: 'volume must be restored after pause');
      expect(timer.isActive, isFalse);
      expect(timer.remaining.value, isNull);
    });

    test('end-of-track mode pauses on a media item transition', () async {
      final target = _FakeTarget();
      final timer = SleepTimer(
        target,
        fadeDuration: const Duration(milliseconds: 10),
        fadeSteps: 2,
      );

      timer.startEndOfTrack();
      expect(timer.pauseWhenSongEnd, isTrue);

      timer.onMediaItemTransition();
      expect(timer.pauseWhenSongEnd, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(target.paused, isTrue);
    });

    test('end-of-track mode pauses when playback completes', () async {
      final target = _FakeTarget();
      final timer = SleepTimer(
        target,
        fadeDuration: const Duration(milliseconds: 10),
        fadeSteps: 2,
      );

      timer.startEndOfTrack();
      timer.onPlaybackCompleted();

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(target.paused, isTrue);
    });

    test('clearing the timer prevents it from pausing', () async {
      final target = _FakeTarget();
      final timer = SleepTimer(
        target,
        fadeDuration: const Duration(milliseconds: 10),
        fadeSteps: 2,
      );

      timer.start(const Duration(milliseconds: 20));
      timer.clear();

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(target.paused, isFalse);
      expect(timer.isActive, isFalse);
    });

    test('starting a new timer replaces the previous one', () async {
      final target = _FakeTarget();
      final timer = SleepTimer(
        target,
        fadeDuration: const Duration(milliseconds: 10),
        fadeSteps: 2,
      );

      timer.start(const Duration(milliseconds: 50));
      timer.start(const Duration(milliseconds: 200));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(target.paused, isFalse, reason: 'first timer must be cancelled');

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(target.paused, isTrue);
    });

    test('a zero duration timer is a no-op', () {
      final timer = SleepTimer(_FakeTarget());
      timer.start(Duration.zero);
      expect(timer.isActive, isFalse);
    });
  });
}
