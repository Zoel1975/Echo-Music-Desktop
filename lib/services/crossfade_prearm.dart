import 'dart:math' as math;

/// Dart port of Android Echo's `AdaptivePreArmManager`.
///
/// The standby player must be fully prepared *well before* the crossfade
/// trigger. Preparing it only inside the fade window made playback freeze for
/// a moment while the stream was resolved/buffered. Lead time grows when
/// preparation is slow and decays toward the 20 s base when it is fast.
class AdaptivePreArmManager {
  AdaptivePreArmManager({
    this.baseLeadTime = const Duration(seconds: 20),
    this.maxLeadTime = const Duration(seconds: 35),
    this.slowPrepThreshold = const Duration(seconds: 8),
  }) : assert(maxLeadTime >= baseLeadTime);

  final Duration baseLeadTime;
  final Duration maxLeadTime;
  final Duration slowPrepThreshold;

  Duration currentLeadTime = const Duration(seconds: 20);
  final List<Duration> _recentPrepTimes = [];

  void recordPreparationDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _recentPrepTimes.add(duration);
    if (_recentPrepTimes.length > 5) _recentPrepTimes.removeAt(0);

    if (duration > slowPrepThreshold) {
      final expansion =
          (duration - slowPrepThreshold) * 1.5;
      final expanded = baseLeadTime + expansion;
      final millis = math.max(currentLeadTime.inMilliseconds, expanded.inMilliseconds);
      currentLeadTime = Duration(
          milliseconds: math.min(maxLeadTime.inMilliseconds, millis));
    } else {
      final average = _recentPrepTimes.fold<Duration>(
            Duration.zero,
            (sum, d) => sum + d,
          ) ~/
          _recentPrepTimes.length;
      if (average < slowPrepThreshold) {
        currentLeadTime = Duration(
          milliseconds: math.max(
            baseLeadTime.inMilliseconds,
            currentLeadTime.inMilliseconds - 2000,
          ),
        );
      }
    }
  }

  void reset() {
    currentLeadTime = baseLeadTime;
    _recentPrepTimes.clear();
  }
}
