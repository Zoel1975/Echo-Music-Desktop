/* Hallmark · macrostructure: Workbench · tone: austere · anchor hue: warm red */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData light({Color? primary}) {
    final seed = primary ?? EchoTokens.seedColor;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
      surface: EchoTokens.paperLight,
      onSurface: EchoTokens.inkLight,
      outline: EchoTokens.ruleLight,
      primary: EchoTokens.accent,
    );
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: EchoTokens.paperLight,
      cardColor: EchoTokens.paper2Light,
      dividerColor: EchoTokens.ruleLight,
      textTheme: appTextTheme(ThemeData.light().textTheme),
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: EchoTokens.paperLight,
        surfaceTintColor: EchoTokens.paperLight,
        foregroundColor: EchoTokens.inkLight,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarColor: EchoTokens.paperLight,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: EchoTokens.paperLight,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
    );
  }

  static ThemeData dark({Color? primary}) {
    final seed = primary ?? EchoTokens.seedColor;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
      surface: EchoTokens.paper,
      onSurface: EchoTokens.ink,
      outline: EchoTokens.rule,
      primary: EchoTokens.accent,
    );
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: EchoTokens.paper,
      cardColor: EchoTokens.paper2,
      dividerColor: EchoTokens.rule,
      textTheme: appTextTheme(ThemeData.dark().textTheme),
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: EchoTokens.paper,
        surfaceTintColor: EchoTokens.paper,
        foregroundColor: EchoTokens.ink,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarColor: EchoTokens.paper,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: EchoTokens.paper,
        ),
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
