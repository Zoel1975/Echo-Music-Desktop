import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../generated/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/echo_sidebar.dart';
import '../../services/update_service/update_service.dart';
import 'widgets/bottom_player.dart';

/// App shell — Hallmark Workbench shape, N9 edge-aligned sidebar only.
/// The floating glass bar and the mobile bottom bar were removed; the sidebar
/// collapses to an icon rail on narrow windows instead.
class AppShell extends StatefulWidget {
  const AppShell({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('AppShell'));

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    UpdateService.autoCheck(context);
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detail/account/login/explore branches have no sidebar tab; the visible
    // rail covers only the four primary branches.
    final tabs = [
      (S.of(context).Home, CupertinoIcons.music_house),
      (S.of(context).Search_Echo, CupertinoIcons.search),
      (S.of(context).Saved, Icons.library_music_outlined),
      (S.of(context).Settings, CupertinoIcons.gear_alt),
    ];
    final selected = widget.navigationShell.currentIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: EchoTokens.paper,
      body: Row(
        children: [
          EchoSidebar(
            selected: selected,
            extended: MediaQuery.of(context).size.width >= 720,
            labels: [for (final tab in tabs) tab.$1],
            icons: [for (final tab in tabs) tab.$2],
            onDestinationSelected: _goBranch,
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: widget.navigationShell),
                const SizedBox(
                  height: EchoTokens.playerHeight,
                  child: BottomPlayer(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
