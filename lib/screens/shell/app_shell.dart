import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/floating_nav.dart';
import '../../generated/l10n.dart';
import '../../services/audio_fallback.dart';
import '../../services/media_player.dart';
import '../../services/update_service/update_service.dart';
import 'echo_shell_chrome.dart';
import 'widgets/bottom_player.dart';

/// App shell: one navigation surface only — the floating glass bar.
/// The desktop NavigationRail and the narrow NavigationBar were removed so
/// the options bar is no longer duplicated. The mini player docks below it,
/// and the section bar slides down into that space when it is empty.
class AppShell extends StatefulWidget {
  const AppShell({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('AppShell'));
  final StatefulNavigationShell navigationShell;

  /// Branch currently highlighted in the floating nav (runtime diagnostics).
  static int? get currentBranchIndex => _AppShellState.lastBranchIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Live branch index, read by the runtime probe to verify that detail pages
  /// highlight the correct tab.
  static int? lastBranchIndex;

  /// Whether the mini player occupies the bottom dock. When it doesn't, the
  /// floating section bar slides down into that space.
  final ValueNotifier<bool> _hasPlayer = ValueNotifier<bool>(false);
  MediaPlayer? _player;

  @override
  void initState() {
    super.initState();
    UpdateService.autoCheck(context);
    if (GetIt.I.isRegistered<MediaPlayer>()) {
      _player = GetIt.I<MediaPlayer>();
      _player!.currentSongNotifier.addListener(_syncPlayerPresence);
      _syncPlayerPresence();
    }
  }

  void _syncPlayerPresence() {
    final visible = _player?.currentSongNotifier.value != null;
    if (_hasPlayer.value != visible) _hasPlayer.value = visible;
  }

  @override
  void dispose() {
    _player?.currentSongNotifier.removeListener(_syncPlayerPresence);
    _hasPlayer.dispose();
    super.dispose();
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
          label: 'Esplora',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          onTap: () => _goBranch(2),
        ),
        EchoNavDestination(
          label: S.of(context).Saved,
          icon: Icons.library_music_outlined,
          selectedIcon: Icons.library_music,
          onTap: () => _goBranch(3),
        ),
        EchoNavDestination(
          label: S.of(context).Settings,
          icon: CupertinoIcons.gear_alt,
          selectedIcon: CupertinoIcons.gear_alt_fill,
          onTap: () => _goBranch(4),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // Same five destinations as Android: Home, Search, Explore, Library, Account.
    final shellIndex = widget.navigationShell.currentIndex.clamp(0, 4);
    _AppShellState.lastBranchIndex = widget.navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: audioFallback,
            builder: (context, silent, _) => silent
                ? MaterialBanner(
                    backgroundColor: Colors.orange.shade900,
                    leading: const Icon(Icons.volume_off, color: Colors.white),
                    content: const Text(
                      'Audio non disponibile: un\'altra app usa l\'uscita audio. '
                      'L\'app funziona, ma la riproduzione è senza suono.',
                      style: TextStyle(color: Colors.white),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => audioFallback.value = false,
                        child: const Text('Chiudi',
                            style: TextStyle(color: Colors.white)),
                      ),
                      TextButton.icon(
                        onPressed: restartWithAudio,
                        icon: const Icon(Icons.restart_alt,
                            color: Colors.white, size: 18),
                        label: const Text('Riavvia con audio',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: EchoShellChrome(
              content: widget.navigationShell,
              bottom: const BottomPlayer(),
              hasPlayer: _hasPlayer,
              selected: shellIndex,
              destinations: _destinations(context),
            ),
          ),
        ],
      ),
    );
  }
}
