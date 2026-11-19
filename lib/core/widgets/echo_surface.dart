import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

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
  });

  final BorderRadius radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ??
        scheme.surfaceVariant.withValues(alpha: EchoTokens.surfaceAlpha);

    return RepaintBoundary(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            padding: padding ?? EdgeInsets.zero,
            decoration: BoxDecoration(color: base, borderRadius: radius),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
