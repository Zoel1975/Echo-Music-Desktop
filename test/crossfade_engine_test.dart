import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/crossfade_engine.dart';

class FakePlayer implements FadeablePlayer {
  double volume = 1.0;
  int setVolumeCalls = 0;
  bool played = false;
  @override
  Future<void> setVolume(double v) async {
    volume = v;
    setVolumeCalls++;
  }

  @override
  Future<void> play() async => played = true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
}

class ManualStopwatch implements Stopwatch {
  int micros = 0;
  @override
  bool get isRunning => true;
  @override
  int get elapsedMilliseconds => micros ~/ 1000;
  @override
  Duration get elapsed => Duration(microseconds: micros);
  @override
  int get elapsedMicroseconds => micros;
  @override
  int get elapsedTicks => micros;
  @override
  int get frequency => 1000000;
  @override
  void start() {}
  @override
  void stop() {}
  @override
  void reset() => micros = 0;
  @override
  void restart() => micros = 0;
}

void main() {
  group('CrossfadeCurve (equal power)', () {
    test('ends are exact', () {
      expect(CrossfadeCurve.fadeIn(0), closeTo(0, 1e-9));
      expect(CrossfadeCurve.fadeOut(0), closeTo(1, 1e-9));
      expect(CrossfadeCurve.fadeIn(1), closeTo(1, 1e-9));
      expect(CrossfadeCurve.fadeOut(1), closeTo(0, 1e-9));
    });

    test('power sums to 1 at every step (no mid-fade dip)', () {
      for (var i = 0; i <= 20; i++) {
        final t = i / 20;
        final sum = CrossfadeCurve.fadeIn(t) * CrossfadeCurve.fadeIn(t) +
            CrossfadeCurve.fadeOut(t) * CrossfadeCurve.fadeOut(t);
        expect(sum, closeTo(1.0, 1e-9));
      }
    });
  });

  test('engine ramps both players and finishes', () async {
    final out = FakePlayer();
    final inn = FakePlayer();
    final sw = ManualStopwatch();
    final engine = CrossfadeEngine(
      out: out,
      inPlayer: inn,
      tick: const Duration(milliseconds: 10),
      stopwatchFactory: () => sw,
    );
    var done = false;
    // duration 100ms, advance to 50% then complete
    await engine.start(const Duration(milliseconds: 100), onDone: () => done = true);
    expect(engine.isRunning, isTrue);

    sw.micros = 50000;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(out.volume, lessThan(1.0));
    expect(inn.volume, greaterThan(0.0));

    sw.micros = 100000;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(done, isTrue);
    expect(engine.isRunning, isFalse);
    expect(out.volume, closeTo(0.0, 1e-6));
    expect(inn.volume, closeTo(1.0, 1e-6));
    engine.dispose();
  });
}
