import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';
import 'typography.dart';

/// Set at startup by the "Theme variant" setting (monochrome).
Color? themeSeedOverride;

class AppTheme {
  /// When "AMOLED black" is on, dark surfaces use pure black instead of the
  /// seeded dark grey. Port of Android's `amoledBlack` preference.
  static ThemeData light({Color? primary, bool amoled = false}) {
    final colorScheme =
        ColorScheme.fromSeed(
            seedColor: primary ?? themeSeedOverride ?? EchoTokens.seedColor,
            brightness: Brightness.light);

    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: appTextTheme(ThemeData.light().textTheme),
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        unselectedIconTheme: const IconThemeData(color: Colors.black),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        indicatorColor: Colors.black,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: const TextStyle(color: Colors.black, fontSize: 11),
        unselectedLabelTextStyle:
            TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 11),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
    );
  }

  static ThemeData dark({Color? primary, bool amoled = false}) {
    final seeded = ColorScheme.fromSeed(
      seedColor: primary ?? themeSeedOverride ?? EchoTokens.seedColor,
      brightness: Brightness.dark,
    );
    final colorScheme = amoled
        ? seeded.copyWith(
            surface: Colors.black,
            onSurface: Colors.white,
            surfaceContainerHighest: const Color(0xFF0A0A0A),
            surfaceContainerLow: Colors.black,
            background: Colors.black,
          )
        : seeded;
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: amoled ? Colors.black : Colors.transparent,
      textTheme: appTextTheme(ThemeData.dark().textTheme),
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        unselectedIconTheme: const IconThemeData(color: Colors.white),
        selectedIconTheme: const IconThemeData(color: Colors.black),
        indicatorColor: Colors.white,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle:
            TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 11),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
    );
  }
}
