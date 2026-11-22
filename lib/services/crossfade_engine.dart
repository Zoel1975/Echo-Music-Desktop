import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Minimal surface of an audio player the crossfade engine needs. Tests supply
/// a fake; [AudioPlayerAdapter] wraps a real just_audio player.
abstract class FadeablePlayer {
  Future<void> setVolume(double volume);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
}

/// Adapts a just_audio [AudioPlayer] to [FadeablePlayer] so the crossfade
/// engine can drive it during a real two-player handoff.
class AudioPlayerAdapter implements FadeablePlayer {
  const AudioPlayerAdapter(this.player);
  final AudioPlayer player;

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);
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

  /// Incremented by [cancel]/[start] so an async tick from an old fade cannot
  /// write volumes over a newer one (that produced audible volume jumps).
  int _generation = 0;
  bool _updating = false;

  /// Peak volume each player is ramped toward (usually 1.0, or lower when
  /// loudness normalization applies a gain).
  double peakVolume = 1.0;

  void cancel() {
    _generation++;
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
    final generation = _generation;
    final sw = _stopwatchFactory()..start();
    _timer = Timer.periodic(tick, (timer) async {
      // setVolume() is async on Windows. Overlapping ticks would apply stale
      // volumes out of order, audible as a stutter/click near the handoff.
      if (_updating || generation != _generation) return;
      _updating = true;
      try {
        final t =
            (sw.elapsedMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
        await out.setVolume(peakVolume * CrossfadeCurve.fadeOut(t));
        await inPlayer.setVolume(peakVolume * CrossfadeCurve.fadeIn(t));
        if (generation != _generation) return;
        if (t >= 1.0) {
          timer.cancel();
          _timer = null;
          _running = false;
          onDone?.call();
        }
      } finally {
        _updating = false;
      }
    });
  }

  void dispose() => cancel();
}
