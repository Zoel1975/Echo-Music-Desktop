import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../services/settings_manager.dart';
import '../theme/tokens.dart';

/// Glass surface — desktop equivalent of Android's `ui/backdrop/*`.
///
/// NOTE: BackdropFilter was removed. On Windows/Impeller it leaked the blur
/// outside the pill and blurred the whole screen behind the mini-player.
/// The glass look is approximated with translucent layered colors, a
/// highlight rim and a soft shadow, which is stable on every backend.
class EchoSurface extends StatelessWidget {
  const EchoSurface({
    super.key,
    this.child,
    this.radius = const BorderRadius.all(Radius.circular(24)),
    this.color,
    this.padding,
    this.blurSigma = 10,
    this.vibrancy = 1.0,
    this.shadow = true,
  });

  final BorderRadius radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final double blurSigma;
  final double vibrancy;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    SettingsManager? settings;
    try {
      settings = GetIt.I<SettingsManager>();
    } catch (_) {}

    final depth = (settings?.extra<double>('blurRadius', blurSigma) ?? blurSigma)
        .clamp(0.0, 24.0);
    final glassEnabled = settings?.extra<bool>('liquidGlass', true) ?? true;
    final vibrancyValue =
        (settings?.extra<double>('vibrancy', 1.0) ?? vibrancy).clamp(0.5, 1.8);

    final base = color ??
        scheme.surfaceVariant.withValues(alpha: EchoTokens.surfaceAlpha);
    // More "glass depth" = a slightly stronger translucent white tint.
    final glassTint = glassEnabled
        ? Colors.white.withValues(
            alpha: (0.03 + (depth / 24) * 0.07).clamp(0.0, 0.10),
          )
        : Colors.transparent;
    final accentTint = scheme.primary.withValues(
      alpha: (0.03 + (vibrancyValue - 1).clamp(0.0, 0.8) * 0.06),
    );

    return RepaintBoundary(
      child: Container(
        padding: padding ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          gradient: glassEnabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [base, glassTint, accentTint],
                  stops: const [0.0, 0.55, 1.0],
                )
              : null,
          color: glassEnabled ? null : base,
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(
              alpha: glassEnabled ? 0.16 : 0.06,
            ),
            width: 1,
          ),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
