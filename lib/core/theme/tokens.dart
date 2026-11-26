import 'dart:ui';

/// Design tokens for the Echo Music desktop port.
///
/// Values are the equivalents of `ui/theme/Theme.kt` + `DESIGN.md` on the
/// Android side ("surfaceVariant @ 0.3", 24/28 dp radii, flat elevation,
/// `RoundedCornerShape(24.dp)` chrome). `kSeedColor` is the colour Android
/// uses to generate the palette (`0xFFED5564`).
class EchoTokens {
  const EchoTokens._();

  /// Seed colour for dynamic palettes (`Theme.kt`'s `0xFFED5564`).
  static const Color seedColor = Color(0xFFED5564);

  // ---------------------------------------------------------------- radii --
  static const double cornerSmall = 16.0;
  static const double cornerMedium = 20.0;
  static const double cornerLarge = 24.0;
  static const double cornerExtraLarge = 28.0;
  static const double pillRadius = 999.0;

  // -------------------------------------------------------------- spacing --
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space7 = 28.0;
  static const double space8 = 32.0;
  static const double space9 = 40.0;

  // ------------------------------------------------------- surfaces ------
  /// Default translucent card background (`surfaceVariant.copy(alpha: 0.3)`).
  static const double surfaceAlpha = 0.3;

  /// Alpha of the translucent grouped-container used by settings sheets.
  static const double groupedContainerAlpha = 0.35;

  /// Glass surface: Apple-style surface tint alpha (4% when light, dark when
  /// dark mode) over the layer, per `GlassEffect.kt`.
  static const double glassOpacity = 0.4;
  static const Color glassTintLight = Color(0xFFFAFAFA);
  static const Color glassTintDark = Color(0xFF121212);

  /// Saturation multiplier applied to glass surfaces (Apple uses ~1.5x).
  static const double glassVibrancy = 1.5;

  /// Radius of a floating chrome capsule (`FloatingTabBar`).
  static const double floatingBarRadius = 20.0;

  /// Status-pill border alpha (White 14% in Android).
  static const double statusPillAlpha = 0.14;

  /// Minimum touch target per WCAG 2.5.5 (and Android convention).
  static const double touchTarget = 48.0;
}
