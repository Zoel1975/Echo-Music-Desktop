import 'dart:async';

import 'package:flutter/foundation.dart';

import 'crossfade_engine.dart';

/// Factory signature for building a crossfade engine for a player pair.
typedef CrossfadeEngineFactory = CrossfadeEngine Function({
  required FadeablePlayer out,
  required FadeablePlayer inPlayer,
});

CrossfadeEngine _defaultEngine({
  required FadeablePlayer out,
  required FadeablePlayer inPlayer,
}) => CrossfadeEngine(out: out, inPlayer: inPlayer);

/// Owns a pair of players and performs a genuine two-player handoff: the
/// outgoing track keeps playing while the incoming track fades in, using the
/// equal-power [CrossfadeEngine]. After the ramp the outgoing player is stopped
/// and the incoming one becomes the active player for the next transition.
///
/// This is the real desktop crossfade (just_audio's ConcatenatingAudioSource
/// alone cannot overlap two tracks).
class TrackCrossfader {
  TrackCrossfader({
    required FadeablePlayer Function() makePlayer,
    CrossfadeEngineFactory? engineFactory,
  })  : _makePlayer = makePlayer,
        _engineFactory = engineFactory ?? _defaultEngine;

  final FadeablePlayer Function() _makePlayer;
  final CrossfadeEngineFactory _engineFactory;

  FadeablePlayer? _active;
  FadeablePlayer? _outgoing;
  CrossfadeEngine? _engine;

  /// The player currently audible (the one the UI/queue should follow).
  FadeablePlayer? get active => _active ??= _makePlayer();

  /// Begin [incoming] over the current track. [startIncoming] is called with
  /// the incoming player so the caller can attach the new source before the
  /// ramp starts. [onDone] fires when the equal-power ramp completes.
  Future<void> crossfadeTo({
    required Duration duration,
    required ValueChanged<FadeablePlayer> startIncoming,
    double peakVolume = 1.0,
    VoidCallback? onDone,
  }) async {
    final incoming = _makePlayer();
    startIncoming(incoming);

    final outgoing = active;
    final engine = _engineFactory(out: outgoing!, inPlayer: incoming)
      ..peakVolume = peakVolume;
    _engine = engine;
    _outgoing = outgoing;

    await incoming.play();
    await engine.start(duration, onDone: () {
      // The previous track is now silent; tear it down and promote the new one.
      outgoing!.pause();
      _active = incoming;
      _outgoing = null;
      _engine = null;
      onDone?.call();
    });
  }

  void cancel() {
    _engine?.cancel();
    _engine = null;
  }

  void dispose() {
    cancel();
    _outgoing = null;
    _active = null;
  }
}
