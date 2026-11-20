import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/core/widgets/floating_nav.dart';
import 'package:Echo/services/update_service/update_service.dart';



import '../../generated/l10n.dart';
import 'widgets/bottom_player.dart';

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

  List<EchoNavDestination> _destinations(BuildContext context) {
    final goBranch = _goBranch;
    return [
      EchoNavDestination(
        label: S.of(context).Home,
        icon: CupertinoIcons.music_house,
        onTap: () => goBranch(0),
      ),
      EchoNavDestination(
        label: S.of(context).Search_Echo,
        icon: CupertinoIcons.search,
        onTap: () => goBranch(1),
      ),
      EchoNavDestination(
        label: S.of(context).Saved,
        icon: Icons.library_music_outlined,
        onTap: () => goBranch(2),
      ),
      EchoNavDestination(
        label: S.of(context).Settings,
        icon: CupertinoIcons.gear_alt,
        onTap: () => goBranch(3),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 450;
    // The shell has 10 route branches (detail/account/login/explore too) but
    // only 4 visible tabs: clamp to avoid NavigationRail/Bar index assertions.
    final shellIndex = widget.navigationShell.currentIndex.clamp(0, 3);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Row(
            children: [
              if (wide)
                NavigationRail(
                  extended: true,
                  backgroundColor: Colors.transparent,
                  groupAlignment: 0.0,
                  destinations: [
                    NavigationRailDestination(
                      selectedIcon: const Icon(
                          CupertinoIcons.music_house_fill,
                          color: Colors.black),
                      icon: const Icon(CupertinoIcons.music_house),
                      label: Text(S.of(context).Home),
                    ),
                    NavigationRailDestination(
                      selectedIcon: const Icon(CupertinoIcons.search,
                          color: Colors.black),
                      icon: const Icon(CupertinoIcons.search),
                      label: Text(S.of(context).Search_Echo),
                    ),
                    NavigationRailDestination(
                        selectedIcon: const Icon(Icons.library_music_outlined,
                            color: Colors.black),
                        icon: const Icon(Icons.library_music_outlined),
                        label: Text(S.of(context).Saved)),
                    NavigationRailDestination(
                        selectedIcon: const Icon(
                            CupertinoIcons.gear_alt_fill,
                            color: Colors.black),
                        icon: const Icon(CupertinoIcons.gear_alt),
                        label: Text(S.of(context).Settings),
                    )
                  ],
                  selectedIndex: shellIndex,
                  onDestinationSelected: _goBranch,
                ),
              Expanded(
                child: widget.navigationShell,
              ),
            ],
          ),
          // Floating glass tab bar â€” the desktop counterpart of Android's
          // FloatingTabBar. See `lib/core/widgets/floating_nav.dart`.
          if (wide)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: EchoFloatingNavBar(
                  selected: shellIndex,
                  destinations: _destinations(context),
                ),
              ),
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: !wide
          ? NavigationBar(
              selectedIndex: shellIndex,
              destinations: [
                NavigationDestination(
                  selectedIcon: const Icon(CupertinoIcons.music_house_fill,
                      color: Colors.black),
                  icon: const Icon(CupertinoIcons.music_house),
                  label: S.of(context).Home,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(CupertinoIcons.search,
                      color: Colors.black),
                  icon: const Icon(CupertinoIcons.search),
                  label: S.of(context).Search_Echo,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(Icons.library_music,
                      color: Colors.black),
                  icon: const Icon(Icons.library_music_outlined),
                  label: S.of(context).Saved,
                ),
                NavigationDestination(
                  selectedIcon: const Icon(CupertinoIcons.settings_solid,
                      color: Colors.black),
                  icon: const Icon(CupertinoIcons.settings),
                  label: S.of(context).Settings,
                ),
              ],
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerLow,
              onDestinationSelected: _goBranch,
            )
          : null,
    );
  }
}
