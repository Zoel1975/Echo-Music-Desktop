/// Player layout modes — port of Android `Player.kt` 3 layouts.
enum PlayerLayout { compact, narrow, wide }

/// Pure layout decision from viewport width (testable).
class PlayerLayoutResolver {
  PlayerLayoutResolver._();

  /// [width] is the available logical width. Thresholds mirror Android:
  /// < 480 compact (phone portrait), < 900 narrow (tablet), else wide.
  static PlayerLayout resolve(double width) {
    if (width < 480) return PlayerLayout.compact;
    if (width < 900) return PlayerLayout.narrow;
    return PlayerLayout.wide;
  }
}
