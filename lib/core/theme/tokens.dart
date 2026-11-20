/* Hallmark · pre-emit critique: P4 H4 E5 S4 R5 V4 */
// Hallmark · macrostructure: Workbench · genre: atmospheric · theme: Midnight
// · nav: N9 edge-aligned · enrichment: none · anchor hue: warm red
import 'dart:ui';

/// Locked design tokens for the Echo Music desktop shell.
///
/// Hallmark rule: no mid-render colour improvisation. Widgets reference these
/// names only. Values are tinted neutrals (never pure black/white) with one
/// warm accent derived from Echo's Android seed `0xFFED5564`.
class EchoTokens {
  const EchoTokens._();

  /// Android `Theme.kt` seed (`0xFFED5564`).
  static const Color seedColor = Color(0xFFED5564);

  // Paper / ink — Midnight register, tinted toward the warm accent.
  static const Color paper = Color(0xFF141215);
  static const Color paper2 = Color(0xFF1C191D);
  static const Color paper3 = Color(0xFF262126);
  static const Color ink = Color(0xFFF2EDEF);
  static const Color ink2 = Color(0xFFB9AFB5);
  static const Color rule = Color(0xFF3A3338);

  /// Legacy glass tokens (kept for the unused `EchoSurface`/floating bar).
  static const double glassOpacity = 0.4;
  static const double glassVibrancy = 1.5;
  static const Color glassTintLight = Color(0xFFFAFAFA);
  static const Color glassTintDark = Color(0xFF121212);
  static const double floatingBarRadius = 20.0;

  /// Legacy translucent-surface alpha (kept for `EchoSurface`).
  static const double surfaceAlpha = 0.3;

  // One accent, used on small surfaces only (never on display text).
  static const Color accent = Color(0xFFED5564);
  static const Color accentSoft = Color(0x2BED5564);
  static const Color focus = Color(0xFFFFB3A0);

  // Light register — still tinted, never #FFFFFF.
  static const Color paperLight = Color(0xFFF7F2F3);
  static const Color paper2Light = Color(0xFFEFE8EA);
  static const Color inkLight = Color(0xFF241E21);
  static const Color ink2Light = Color(0xFF6E6268);
  static const Color ruleLight = Color(0xFFD9CDD1);

  // Radii — 4 pt discipline, one containment layer.
  static const double cornerSmall = 16.0;
  static const double cornerMedium = 20.0;
  static const double cornerLarge = 24.0;
  static const double cornerExtraLarge = 28.0;
  static const double pillRadius = 999.0;

  // Spacing — 4 pt named scale.
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space7 = 28.0;
  static const double space8 = 32.0;
  static const double space9 = 40.0;

  // Chrome dimensions — edge-aligned rail, no floating chrome.
  static const double railWidth = 208.0;
  static const double railWidthCompact = 72.0;
  static const double touchTarget = 48.0;
  static const double playerHeight = 64.0;
  static const double motionFast = 140.0;
  static const double motionBase = 220.0;
}
