import 'package:flutter/material.dart';

import '../core/theme/motion_tokens.dart';

/// A quiet fade + short upward slide used for pushes inside the app.
/// The old code used a full-height slide, which felt heavy on desktop and
/// made page order hard to follow.
class EchoPage<T> extends Page<T> {
  const EchoPage({
    required this.child,
    super.key,
    this.name,
    this.offset = const Offset(0, 0.012),
  });

  final Widget child;
  @override
  final String? name;
  final Offset offset;

  @override
  Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
        settings: this,
        transitionDuration: MotionTokens.page,
        reverseTransitionDuration: MotionTokens.micro,
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: MotionTokens.standard,
            reverseCurve: MotionTokens.reverse,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: offset, end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      );
}
