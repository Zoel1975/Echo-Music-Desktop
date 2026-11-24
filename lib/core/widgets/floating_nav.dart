import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/settings_manager.dart';

import '../theme/motion_tokens.dart';
import '../theme/tokens.dart';

/// A destination on the desktop floating bottom bar.
@immutable
class EchoNavDestination {
  const EchoNavDestination({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback onTap;
  final Widget? badge;
}

/// Floating bottom bar — the desktop equivalent of Android's
/// `FloatingTabBar`/`FloatingNavigationToolbar`.
///
/// A centered, glass (backdrop blur), radius `EchoTokens.floatingBarRadius`
/// capsule with a soft shadow and 48dp touch targets. Positioning is left to
/// the caller (`Positioned`), so the bar can sit above the docked mini player.
class EchoFloatingNavBar extends StatelessWidget {
  const EchoFloatingNavBar({
    super.key,
    required this.selected,
    required this.destinations,
  });

  final int selected;
  final List<EchoNavDestination> destinations;

  @override
  @override
  Widget build(BuildContext context) {
    // Glass / navigation style preferences are read from SettingsManager via
    // GetIt. AnimatedBuilder subscribes to the ChangeNotifier without needing
    // a Provider ancestor (tests and embedded surfaces may not have one).
    if (!GetIt.I.isRegistered<SettingsManager>()) return _buildBar(context);
    return AnimatedBuilder(
      animation: GetIt.I<SettingsManager>(),
      builder: (context, _) => _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // No BackdropFilter: on Windows/Impeller it leaked the blur outside the
    // pill and blurred the whole app. Same look, stable layered colors.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: () {
          // Tests render the bar without the DI container; default to glass.
          bool glass = true;
          if (GetIt.I.isRegistered<SettingsManager>()) {
            glass = GetIt.I<SettingsManager>().extra<bool>('glassNavBar', true);
          }
          return glass
              ? Color.alphaBlend(
                  scheme.surfaceVariant.withValues(alpha: 0.55),
                  scheme.surface.withValues(alpha: 0.92),
                )
              : scheme.surface;
        }(),
        borderRadius: BorderRadius.circular(
          GetIt.I.isRegistered<SettingsManager>() &&
                  GetIt.I<SettingsManager>()
                          .extra<String>('navBarStyle', 'Apple (floating)') ==
                      'Material'
              ? 4
              : EchoTokens.floatingBarRadius,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(destinations.length, (i) {
              final d = destinations[i];
              final isSelected = i == selected;
              final color = isSelected ? scheme.primary : scheme.onSurface;
              return AnimatedContainer(
                duration: MotionTokens.micro,
                curve: MotionTokens.standard,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  tooltip: d.label,
                  icon: AnimatedScale(
                    scale: isSelected ? 1.12 : 1.0,
                    duration: MotionTokens.micro,
                    curve: MotionTokens.emphasized,
                    child: AnimatedSwitcher(
                      duration: MotionTokens.micro,
                      switchInCurve: MotionTokens.standard,
                      child: Icon(
                        isSelected ? (d.selectedIcon ?? d.icon) : d.icon,
                        key: ValueKey<bool>(isSelected),
                        size: 20,
                        color: color,
                      ),
                    ),
                  ),
                  onPressed: d.onTap,
                ),
              );
            }),
              if (GetIt.I.isRegistered<SettingsManager>() &&
                  GetIt.I<SettingsManager>()
                      .extra<bool>('listenTogetherTop', false))
                IconButton(
                  tooltip: 'Ascolto condiviso',
                  icon: const Icon(Icons.groups, size: 20),
                  onPressed: () => context
                      .go('/settings/integrations/listen_together'),
                ),
            ],
      ),
    );
  }
}

