import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Minimal surface of an audio player the crossfade engine needs. `AudioPlayer`
/// from just_audio satisfies it; tests supply a fake.
abstract class FadeablePlayer {
  Future<void> setVolume(double volume);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
}

/// Equal-power (constant-perceived-loudness) crossfade between two players.
///
/// `fadeIn(t) = sin(t * PI/2)`, `fadeOut(t) = cos(t * PI/2)` so that
/// `fadeIn^2 + fadeOut^2 == 1` at every instant — no volume dip in the middle,
/// which a linear ramp would cause.
class CrossfadeCurve {
  const CrossfadeCurve._();

  static double fadeIn(double t) => math.sin(t.clamp(0.0, 1.0) * math.pi / 2);
  static double fadeOut(double t) => math.cos(t.clamp(0.0, 1.0) * math.pi / 2);
}

/// Drives a crossfade from [out] to [inPlayer] over [duration], ramping both
/// volumes on each [tick]. Owns its timer so it can be cancelled/restarted.
class CrossfadeEngine {
  CrossfadeEngine({
    required this.out,
    required this.inPlayer,
    this.tick = const Duration(milliseconds: 50),
    Stopwatch Function()? stopwatchFactory,
  }) : _stopwatchFactory = stopwatchFactory ?? Stopwatch.new;

  final FadeablePlayer out;
  final FadeablePlayer inPlayer;
  final Duration tick;
  final Stopwatch Function() _stopwatchFactory;

  Timer? _timer;
  bool _running = false;
  bool get isRunning => _running;

  /// Peak volume each player is ramped toward (usually 1.0, or lower when
  /// loudness normalization applies a gain).
  double peakVolume = 1.0;

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// Start the ramp. `onDone` fires once both ends are reached.
  Future<void> start(Duration duration, {VoidCallback? onDone}) async {
    cancel();
    if (duration <= Duration.zero) {
      await out.setVolume(0);
      await inPlayer.setVolume(peakVolume);
      _running = false;
      onDone?.call();
      return;
    }

    _running = true;
    final sw = _stopwatchFactory()..start();
    _timer = Timer.periodic(tick, (timer) async {
      final t = (sw.elapsedMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      await out.setVolume(peakVolume * CrossfadeCurve.fadeOut(t));
      await inPlayer.setVolume(peakVolume * CrossfadeCurve.fadeIn(t));
      if (t >= 1.0) {
        timer.cancel();
        _timer = null;
        _running = false;
        onDone?.call();
      }
    });
  }

  void dispose() => cancel();
}
