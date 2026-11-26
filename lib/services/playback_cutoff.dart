import 'dart:math' as math;

/// Pure port of Android `PlaybackCutoffGuard` + `AdaptivePreArmManager`:
/// decides when to pre-arm the next track to avoid a playback gap at the end
/// of the current one, adapting the threshold to remaining buffer.
class PlaybackCutoffGuard {
  PlaybackCutoffGuard._();

  /// [remaining] and [buffered] in milliseconds; [position] in milliseconds.
  /// Returns true when the next source should be pre-armed.
  static bool shouldPreArm({
    required int positionMs,
    required int durationMs,
    required int bufferedMs,
    required int baseLeadMs,
  }) {
    if (durationMs <= 0) return false;
    final remaining = durationMs - positionMs;
    if (remaining <= 0) return false;
    // If buffering is short, arm earlier; if healthy, use the base lead.
    final bufferedAhead = math.max(0, bufferedMs - positionMs);
    final adaptiveLead = bufferedAhead < baseLeadMs
        ? (baseLeadMs * 1.5).round()
        : baseLeadMs;
    return remaining <= adaptiveLead;
  }

  /// Cap the feed size to avoid unbounded memory (Android MAX_FEED_SIZE).
  static int cappedFeedSize(int current, int max) => math.min(current, max);
}
