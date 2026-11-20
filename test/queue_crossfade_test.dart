import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/crossfade_engine.dart';
import 'package:Echo/services/queue_crossfade.dart';

class FakePlayer implements FadeablePlayer {
  double volume = 1.0;
  bool playing = false;
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> seek(Duration position) async {}
}

void main() {
  test('CrossfadeDecision only enables when crossfade on and was playing', () {
    final on = CrossfadeDecision.evaluate(
      crossfadeEnabled: true,
      wasPlaying: true,
      userVolume: 1.0,
      targetGain: 1.0,
    );
    expect(on.enabled, isTrue);
    expect(on.peakVolume, 1.0);

    expect(
      CrossfadeDecision.evaluate(
        crossfadeEnabled: false,
        wasPlaying: true,
        userVolume: 1.0,
        targetGain: 1.0,
      ).enabled,
      isFalse,
    );
    expect(
      CrossfadeDecision.evaluate(
        crossfadeEnabled: true,
        wasPlaying: false,
        userVolume: 1.0,
        targetGain: 1.0,
      ).enabled,
      isFalse,
    );
  });

  test('CrossfadeDecision peak respects normalization gain and clamps', () {
    final d = CrossfadeDecision.evaluate(
      crossfadeEnabled: true,
      wasPlaying: true,
      userVolume: 0.8,
      targetGain: 0.5,
    );
    expect(d.peakVolume, closeTo(0.4, 1e-9));
    final capped = CrossfadeDecision.evaluate(
      crossfadeEnabled: true,
      wasPlaying: true,
      userVolume: 1.0,
      targetGain: 2.0,
    );
    expect(capped.peakVolume, lessThanOrEqualTo(1.0));
  });

  test('QueueCrossfadeController overlaps two real (fake) players', () async {
    final outgoing = FakePlayer();
    final incoming = FakePlayer();
    final controller = QueueCrossfadeController(makePlayer: () => outgoing);
    var attached = false;
    var done = false;

    await controller.start(
      incoming: incoming,
      duration: const Duration(milliseconds: 40),
      peakVolume: 1.0,
      startOutgoing: (p) async => attached = true,
      onDone: () => done = true,
    );
    expect(attached, isTrue);
    expect(outgoing.playing, isTrue);
    expect(controller.isCrossfading, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(done, isTrue);
    expect(outgoing.playing, isFalse);
    expect(controller.isCrossfading, isFalse);
    controller.dispose();
  });
}
