import 'package:flutter/material.dart';

/// Single source of truth for typography, matching Android's
/// `FontSelectionScreen` choices. Set once at startup from SettingsManager.
class AppFonts {
  AppFonts._();

  static const choices = <String, String>{
    'Google Sans Flex': 'GoogleSansFlex',
    'Sans Flex': 'GoogleSansFlex',
    'Outfit': 'Outfit',
    'Plus Jakarta Sans': 'PlusJakartaSans',
    'BBH Bartle': 'BBHBartle',
    'Poppins': 'Poppins',
  };

  static String family = 'GoogleSansFlex';

  static void initialize(String choice) =>
      family = choices[choice] ?? 'GoogleSansFlex';

  static TextStyle style({FontWeight? weight, double? fontSize, Color? color}) =>
      TextStyle(
    fontFamily: family,
    fontWeight: weight,
    fontSize: fontSize,
    color: color,
  );

  static TextStyle applyTo(TextStyle style) =>
      style.copyWith(fontFamily: family);
}
