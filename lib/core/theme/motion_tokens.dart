import 'package:flutter/material.dart';

/// One place for every timing used in the app, so motion feels consistent
/// instead of a different duration on every screen.
abstract final class MotionTokens {
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration page = Duration(milliseconds: 260);
  static const Duration section = Duration(milliseconds: 340);
  static const Duration skeleton = Duration(milliseconds: 1200);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve reverse = Curves.easeInCubic;
}
