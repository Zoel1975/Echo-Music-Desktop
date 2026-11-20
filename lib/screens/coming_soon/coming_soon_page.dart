import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A shared placeholder screen for mobile features that are not yet feasible
/// on desktop. It tells the user the feature is planned for a future update
/// instead of leaving a dead/missing menu item.
///
/// Android-only capabilities (media sessions, Bluetooth/Android Auto triggers,
/// system widgets, ringtones, USB-DAC bit-perfect output, on-device song
/// recognition) have no desktop equivalent yet and route here from Settings.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    this.feature,
  });

  final String title;
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                feature ??
                    'This feature from the mobile app is not available on '
                        'desktop yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Planned for a future update',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
