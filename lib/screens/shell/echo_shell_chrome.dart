import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:Echo/core/theme/motion_tokens.dart';
import 'package:Echo/core/widgets/floating_nav.dart';

/// A listenable that never changes. Used when the caller has no player state,
/// so the bar keeps its historical position above the bottom dock.
class _ConstantPlayerPresence extends ValueListenable<bool> {
  const _ConstantPlayerPresence(this.value);

  @override
  final bool value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

final ValueListenable<bool> _playerPresent =
    const _ConstantPlayerPresence(true);

/// The desktop shell chrome: exactly ONE options/navigation bar — the floating
/// glass bar. Extracted from `AppShell` so its structure can be unit-tested
/// (regression guard against a second NavigationRail / NavigationBar being
/// reintroduced).
///
/// [content] is the active navigation branch; [bottom] is the docked mini
/// player. Both are supplied by the caller so this widget stays dependency
/// free and trivial to pump in a test. When [hasPlayer] reports that nothing
/// is playing, the section bar slides down into the player's empty dock.
class EchoShellChrome extends StatelessWidget {
  const EchoShellChrome({
    super.key,
    required this.content,
    required this.bottom,
    required this.selected,
    required this.destinations,
    this.hasPlayer,
  });

  final Widget content;
  final Widget bottom;
  final int selected;
  final List<EchoNavDestination> destinations;
  final ValueListenable<bool>? hasPlayer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pin content to the viewport: an unpositioned child can grow the
        // Stack past the screen and push the bottom bar off-screen.
        Positioned.fill(child: RepaintBoundary(child: content)),
        ValueListenableBuilder<bool>(
          valueListenable: hasPlayer ?? _playerPresent,
          builder: (context, playing, child) => AnimatedPositioned(
            duration: MotionTokens.micro,
            curve: MotionTokens.standard,
            // 76 leaves room for the docked mini player; with no track the
            // section bar moves down and reclaims that space.
            bottom: playing ? 76 : 12,
            left: 0,
            right: 0,
            child: child!,
          ),
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
