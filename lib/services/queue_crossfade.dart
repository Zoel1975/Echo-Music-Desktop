import 'dart:async';

import 'package:flutter/foundation.dart';

import 'crossfade_engine.dart';

/// Result of deciding whether a track transition should crossfade, and at what
/// peak volume. Pure + unit-testable; mirrors Android's crossfade decision.
class CrossfadeDecision {
  const CrossfadeDecision._(this.enabled, this.peakVolume);

  final bool enabled;
  final double peakVolume;

  static CrossfadeDecision evaluate({
    required bool crossfadeEnabled,
    required bool wasPlaying,
    required double userVolume,
    required double targetGain,
  }) {
    if (!crossfadeEnabled || !wasPlaying) {
      return const CrossfadeDecision._(false, 1.0);
    }
    // Keep total loudness constant: the outgoing and incoming peaks sum to the
    // user volume, modulated by the normalization gain.
    final peak = (userVolume * targetGain).clamp(0.0, 1.0);
    return CrossfadeDecision._(peak > 0, peak);
  }
}

/// Owns a dedicated "outgoing" player so a track switch can overlap the old
/// and new audio using the equal-power [CrossfadeEngine], instead of cutting
/// abruptly. [makePlayer] injects `AudioPlayer` in production and a fake in
/// tests.
class QueueCrossfadeController {
  QueueCrossfadeController({
    required FadeablePlayer Function() makePlayer,
  }) : _makePlayer = makePlayer;

  final FadeablePlayer Function() _makePlayer;
  FadeablePlayer? _outgoing;
  CrossfadeEngine? _engine;

  bool get isCrossfading => _engine?.isRunning ?? false;

  /// Start the overlap: [startOutgoing] attaches/positions the old track on
  /// the outgoing player, [incoming] is the new active player (already at 0),
  /// and [duration] is the crossfade length.
  Future<void> start({
    required FadeablePlayer incoming,
    required Duration duration,
    required double peakVolume,
    required Future<void> Function(FadeablePlayer outgoing) startOutgoing,
    VoidCallback? onDone,
  }) async {
    cancel();
    final outgoing = _makePlayer();
    _outgoing = outgoing;
    await startOutgoing(outgoing);
    await incoming.setVolume(0);
    await outgoing.play();

    final engine = CrossfadeEngine(out: outgoing, inPlayer: incoming)
      ..peakVolume = peakVolume;
    _engine = engine;
    await engine.start(duration, onDone: () {
      outgoing.pause();
      _engine = null;
      _outgoing = null;
      onDone?.call();
    });
  }

  void cancel() {
    _engine?.cancel();
    _engine = null;
    _outgoing = null;
  }

  void dispose() => cancel();
}
