/* Hallmark · pre-emit critique: P4 H4 E5 S5 R5 V4 */
// Hallmark · component: nav N9 edge-aligned · genre: atmospheric · theme: Midnight
// states: default · selected · focus · disabled(n/a) · loading(n/a) · error(n/a) · success(n/a)
import 'package:flutter/material.dart';

import 'package:Echo/core/theme/tokens.dart';

/// Solid, edge-aligned sidebar. No glass, no floating pill, no shadow.
/// One containment layer; the accent appears only on the selected marker.
class EchoSidebar extends StatelessWidget {
  const EchoSidebar({
    super.key,
    required this.selected,
    required this.labels,
    required this.icons,
    required this.onDestinationSelected,
    this.extended = true,
  });

  final int selected;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final width = extended ? EchoTokens.railWidth : EchoTokens.railWidthCompact;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: EchoTokens.paper2,
        border: Border(right: BorderSide(color: EchoTokens.rule, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 68,
            child: Align(
              alignment: extended
                  ? Alignment.centerLeft
                  : Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EchoTokens.space4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: EchoTokens.accent,
                    ),
                    if (extended) ...[
                      const SizedBox(width: EchoTokens.space3),
                      const Text(
                        'ECHO',
                        style: TextStyle(
                          color: EchoTokens.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: EchoTokens.rule),
          const SizedBox(height: EchoTokens.space4),
          for (var i = 0; i < labels.length; i++)
            _SidebarItem(
              label: labels[i],
              icon: icons[i],
              selected: i == selected,
              extended: extended,
              onTap: () => onDestinationSelected(i),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? EchoTokens.ink : EchoTokens.ink2;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          focusColor: EchoTokens.accentSoft,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: selected ? 24 : 0,
                  color: EchoTokens.accent,
                ),
                SizedBox(width: extended ? EchoTokens.space5 : EchoTokens.space3),
                Icon(icon, size: 20, color: color),
                if (extended) ...[
                  const SizedBox(width: EchoTokens.space4),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
