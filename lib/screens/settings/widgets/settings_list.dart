import 'package:flutter/material.dart';

/// Maximum content width shared by every settings screen. Without it some
/// pages stretched tiles across the whole window while others were centered,
/// so identical tiles had different widths and group titles did not line up.
const double settingsMaxWidth = 1000.0;

/// Explicit marker for Android options that have no desktop implementation.
/// The port keeps them visible for parity, but they must never look active.
class SettingNoticeTile extends StatelessWidget {
  const SettingNoticeTile({
    this.message =
        'Alcune opzioni qui sono placeholder dell\'app Android e non hanno '
            'ancora effetto su desktop.',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard settings body: centered, width-capped and consistently padded.
/// Use this instead of a bare [ListView] so all settings screens match.
class SettingsList extends StatelessWidget {
  const SettingsList({
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: settingsMaxWidth),
        child: ListView(padding: padding, children: children),
      ),
    );
  }
}
