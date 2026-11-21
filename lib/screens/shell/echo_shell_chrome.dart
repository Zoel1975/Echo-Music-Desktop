import 'package:flutter/material.dart';

import 'package:Echo/core/theme/motion_tokens.dart';
import 'package:Echo/core/widgets/floating_nav.dart';

/// The desktop shell chrome: exactly ONE options/navigation bar — the floating
/// glass bar. Extracted from `AppShell` so its structure can be unit-tested
/// (regression guard against a second NavigationRail / NavigationBar being
/// reintroduced).
///
/// [content] is the active navigation branch; [bottom] is the docked mini
/// player. Both are supplied by the caller so this widget stays dependency
/// free and trivial to pump in a test.
class EchoShellChrome extends StatelessWidget {
  const EchoShellChrome({
    super.key,
    required this.content,
    required this.bottom,
    required this.selected,
    required this.destinations,
  });

  final Widget content;
  final Widget bottom;
  final int selected;
  final List<EchoNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pin content to the viewport: an unpositioned child can grow the
        // Stack past the screen and push the bottom:76 bar off-screen.
        Positioned.fill(child: RepaintBoundary(child: content)),
        Positioned(
          bottom: 76,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center,
            child: EchoFloatingNavBar(
              selected: selected.clamp(0, destinations.length - 1),
              destinations: destinations,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          // The mini player slides into place instead of popping over the nav.
          child: AnimatedSize(
            duration: MotionTokens.micro,
            curve: MotionTokens.standard,
            alignment: Alignment.bottomCenter,
            child: bottom,
          ),
        ),
      ],
    );
  }
}
