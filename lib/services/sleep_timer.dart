import 'dart:async';

import 'package:flutter/foundation.dart';

/// The part of an audio player the sleep timer needs.
///
/// Kept as an interface so the timer can be unit-tested without a real
/// player, and so the same logic can later back a different engine.
abstract class SleepTimerTarget {
  double get volume;
  set volume(double value);
  Future<void> pause();
}

/// Desktop port of `playback/SleepTimer.kt`.
///
/// Behaviour is taken from the Android source:
///  * a timed sleep timer fades the volume out over 3 s in 30 steps, pauses,
///    then restores the previous volume;
///  * "end of track" mode pauses (with the same fade) on the next media item
///    transition or when playback ends.
class SleepTimer extends ChangeNotifier {
  SleepTimer(
    this._target, {
    this.fadeDuration = const Duration(seconds: 3),
    this.fadeSteps = 30,
  });

  final SleepTimerTarget _target;
  final Duration fadeDuration;
  final int fadeSteps;

  /// Remaining time of a timed timer, or `null` when no timed timer is active.
  final ValueNotifier<Duration?> remaining = ValueNotifier<Duration?>(null);

  DateTime? _triggerAt;
  Timer? _expiry;
  Timer? _ticker;
  bool _pauseWhenSongEnd = false;
  bool _fading = false;

  bool get isActive => _triggerAt != null || _pauseWhenSongEnd;

  bool get pauseWhenSongEnd => _pauseWhenSongEnd;

  /// Starts (or restarts) a timed timer. Non-positive durations clear it.
  void start(Duration duration) {
    clear();
    if (duration <= Duration.zero) return;

    _triggerAt = DateTime.now().add(duration);
    _emitRemaining(_triggerAt!.difference(DateTime.now()));

    // Exact expiry, independent of the UI ticker so short durations behave
    // the same in tests and in production.
    _expiry = Timer(duration, () {
      _triggerAt = null;
      _ticker?.cancel();
      _ticker = null;
      remaining.value = null;
      unawaited(_fadeOutAndPause());
    });

    // Countdown for the UI, driven once per second like the Android sheet.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final triggerAt = _triggerAt;
      if (triggerAt == null) return;
      _emitRemaining(triggerAt.difference(DateTime.now()));
    });

    notifyListeners();
  }

  /// "Pause when the current song ends" mode.
  void startEndOfTrack() {
    clear();
    _pauseWhenSongEnd = true;
    notifyListeners();
  }

  void clear() {
    _expiry?.cancel();
    _expiry = null;
    _ticker?.cancel();
    _ticker = null;
    _triggerAt = null;
    _pauseWhenSongEnd = false;
    remaining.value = null;
    notifyListeners();
  }

  /// Call when the player moves to another media item
  /// (`PlaybackQueue.currentIndexStream`).
  void onMediaItemTransition() {
    if (!_pauseWhenSongEnd) return;
    _pauseWhenSongEnd = false;
    notifyListeners();
    unawaited(_fadeOutAndPause());
  }

  /// Call when playback reaches the end of the last item.
  void onPlaybackCompleted() {
    if (!_pauseWhenSongEnd) return;
    _pauseWhenSongEnd = false;
    notifyListeners();
    unawaited(_fadeOutAndPause());
  }

  void _emitRemaining(Duration left) {
    remaining.value = left.isNegative ? Duration.zero : left;
  }

  Future<void> _fadeOutAndPause() async {
    if (_fading) return;
    _fading = true;
    final initialVolume = _target.volume;
    final steps = fadeSteps <= 0 ? 1 : fadeSteps;
    final stepDelay = Duration(
      microseconds: fadeDuration.inMicroseconds ~/ steps,
    );

    try {
      for (var i = steps; i >= 1; i--) {
        _target.volume = initialVolume * (i / steps);
        if (stepDelay > Duration.zero) {
          await Future<void>.delayed(stepDelay);
        }
      }
      await _target.pause();
    } finally {
      _target.volume = initialVolume;
      _fading = false;
    }
  }
}
