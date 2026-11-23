import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../services/settings_manager.dart';

import '../theme/tokens.dart';

/// Glass surface — the desktop equivalent of `ui/backdrop/*` + the glass
/// rule in `DESIGN.md` (`surfaceVariant @ 0.3`, flat elevation).
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
    final effectiveBlur = settings?.extra<double>('blurRadius', blurSigma) ??
        blurSigma;
    final effectiveVibrancy =
        settings?.extra<double>('vibrancy', 1.0) ?? vibrancy;
    final glassEnabled =
        settings?.extra<bool>('liquidGlass', true) ?? true;
    final tinted = color ??
        scheme.surfaceVariant.withValues(alpha: EchoTokens.surfaceAlpha);
    // Android's glass applies color controls (saturation/vibrancy) to the
    // recorded backdrop. Flutter can only approximate that with a tint blend.
    final base = effectiveVibrancy == 1.0
        ? tinted
        : Color.lerp(
            tinted,
            scheme.primary.withValues(alpha: tinted.a),
            (effectiveVibrancy - 1).clamp(0.0, 1.0) * 0.4,
          ) ?? tinted;

    Widget content = Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: base,
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child ?? const SizedBox.shrink(),
    );
    if (!glassEnabled) {
      return RepaintBoundary(child: content);
    }

    return RepaintBoundary(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
