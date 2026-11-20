import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/core/widgets/floating_nav.dart';
import 'package:Echo/services/update_service/update_service.dart';

import '../../generated/l10n.dart';
import 'echo_shell_chrome.dart';
import 'widgets/bottom_player.dart';

/// App shell: one navigation surface only — the floating glass bar.
/// The desktop NavigationRail and the narrow NavigationBar were removed so
/// the options bar is no longer duplicated. The mini player docks below it.
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

  List<EchoNavDestination> _destinations(BuildContext context) => [
        EchoNavDestination(
          label: S.of(context).Home,
          icon: CupertinoIcons.music_house,
          selectedIcon: CupertinoIcons.music_house_fill,
          onTap: () => _goBranch(0),
        ),
        EchoNavDestination(
          label: S.of(context).Search_Echo,
          icon: CupertinoIcons.search,
          onTap: () => _goBranch(1),
        ),
        EchoNavDestination(
          label: S.of(context).Saved,
          icon: Icons.library_music_outlined,
          selectedIcon: Icons.library_music,
          onTap: () => _goBranch(2),
        ),
        EchoNavDestination(
          label: S.of(context).Settings,
          icon: CupertinoIcons.gear_alt,
          selectedIcon: CupertinoIcons.gear_alt_fill,
          onTap: () => _goBranch(3),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // Detail/account/login/explore are also shell branches; clamp so the
    // floating bar never points past its four visible destinations.
    final shellIndex = widget.navigationShell.currentIndex.clamp(0, 3);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EchoShellChrome(
        content: widget.navigationShell,
        bottom: const BottomPlayer(),
        selected: shellIndex,
        destinations: _destinations(context),
      ),
    );
  }
}
