import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/screens/browse/browse_page.dart';
import 'package:Echo/screens/chip/chip_page.dart';
import 'package:Echo/screens/home/home_page.dart';
import 'package:Echo/screens/chart/chart_details_page.dart';
import 'package:Echo/services/chart_model.dart';
import 'package:Echo/screens/library/downloads/downloading/downloading_page.dart';
import 'package:Echo/screens/library/downloads/downloads_page.dart';
import 'package:Echo/screens/library/downloads/playlist/download_playlist_page.dart';
import 'package:Echo/screens/library/favourites/favourites_page.dart';
import 'package:Echo/screens/library/history/history_page.dart';
import 'package:Echo/screens/library/library_page.dart';
import 'package:Echo/screens/library/playlist/playlist_details_page.dart';
import 'package:Echo/screens/player/player_page.dart';
import 'package:Echo/screens/search/search_page.dart';
import 'package:Echo/screens/settings/about/about_page.dart';
import 'package:Echo/screens/settings/appearance/appearance_page.dart';
import 'package:Echo/screens/coming_soon/coming_soon_page.dart';

import 'package:Echo/screens/settings/backup_storage/backup_storage_page.dart';
import 'package:Echo/screens/settings/player/equalizer/equalizer_page.dart';
import 'package:Echo/screens/settings/player/player_settings_page.dart';
import 'package:Echo/screens/settings/privacy/privacy_page.dart';
import 'package:Echo/screens/settings/services/yt_music/yt_music_page.dart';
import 'package:Echo/screens/settings/settings_page.dart';
import 'package:Echo/screens/detail/album_page.dart';
import 'package:Echo/screens/detail/artist_page.dart';
import 'package:Echo/screens/detail/playlist_page.dart';
import 'package:Echo/screens/account/account_page.dart';
import 'package:Echo/screens/explore/explore_page.dart';
import 'package:Echo/screens/login/login_page.dart';
import 'package:Echo/screens/shell/app_shell.dart';

GoRouter router = GoRouter(
  initialLocation: Platform.environment['ECHO_START_ROUTE'] ?? '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        StatefulShellRoute(
          branches: branches,
          builder: (context, state, navigationShell) => AppShell(
            navigationShell: navigationShell,
          ),
          navigatorContainerBuilder: (context, navigationShell, children) =>
              MyPageView(
            currentIndex: navigationShell.currentIndex,
            children: children,
          ),
        ),
        GoRoute(
          path: '/player',
          pageBuilder: (context, state) {
            final videoId = state.extra as String?;
            return CustomTransitionPage(
              key: state.pageKey,
              child: PlayerPage(videoId: videoId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                final curve = Curves.ease;
                final tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),
      ],
    ),
    // /login is a full-screen route outside the shell: building the WebView2
    // branch eagerly at startup produced invalid surface geometry errors.
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
  ],
);

List<StatefulShellBranch> branches = [
  StatefulShellBranch(
    routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'chip',
              builder: (context, state) {
                Map<String, dynamic> args = state.extra as Map<String, dynamic>;
                return ChipPage(
                    title: args['title'] ?? '',
                    endpoint: args['endpoint'] ?? {});
              },
            ),
            GoRoute(
              path: 'browse',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return BrowsePage(
                  endpoint: args['endpoint'] as Map<String, dynamic>,
                  isMore: args['isMore'] as bool? ?? false,
                );
              },
            ),
            GoRoute(
              path: 'chart_details',
              builder: (context, state) {
                final args = state.extra as ChartURL;
                return ChartDetailsPage(chartUrl: args);
              },
            ),

          ]),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return SearchPage(
            endpoint: args?['endpoint'] as Map<String, dynamic>?,
            isMore: args?['isMore'] as bool? ?? false,
          );
        },
      ),
    ],
  ),
  StatefulShellBranch(routes: [
    GoRoute(
      path: '/saved',
      builder: (context, state) => const LibraryPage(),
      routes: [
        GoRoute(
          path: 'favourites_page',
          builder: (context, state) => const FavouritesPage(),
        ),
        GoRoute(
          path: 'downloads_page',
          builder: (context, state) => const DownloadsPage(),
          routes: [
            GoRoute(
              path: 'download_playlist_page',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>;
                return DownloadPlaylistPage(
                  playlistId: args['playlistId'] as String,
                );
              },
            ),
            GoRoute(
              path: 'downloading_page',
              builder: (context, state) => const DownloadingPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'history_page',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: 'playlist_details',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>;
            return PlaylistDetailsPage(
              playlistkey: args['playlistkey'] as String,
            );
          },
        ),
      ],
    ),
  ]),
  StatefulShellBranch(routes: [
    GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
        routes: [

            GoRoute(
            path: 'appearance',
            builder: (context, state) => const AppearancePage(),
          ),
          GoRoute(
            path: 'coming_soon',
            builder: (context, state) => ComingSoonPage(
              title: (state.extra as Map<String, dynamic>?)?['title'] as String? ??
                  'Coming soon',
              feature: (state.extra as Map<String, dynamic>?)?['feature'] as String?,
            ),
          ),
          GoRoute(
              path: 'player',
              builder: (context, state) => const PlayerSettingsPage(),
              routes: [
                GoRoute(
                  path: 'equalizer',
                  builder: (context, state) => const EqualizerPage(),
                )
              ]),
          GoRoute(
            path: 'services/ytmusic',
            builder: (context, state) => const YTMusicPage(),
          ),
          GoRoute(
            path: 'backup_storage',
            builder: (context, state) => const BackupStoragePage(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyPage(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutPage(),
          ),
        ]),
  ]),
  // --- Phase 3 detail pages (Album / Artist / Online Playlist) ---
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/album',
        builder: (context, state) {
          final browseId =
              (state.extra as Map<String, dynamic>)['browseId'];
          return AlbumPage(browseId: browseId as String);
        },
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/artist',
        builder: (context, state) {
          final browseId =
              (state.extra as Map<String, dynamic>)['browseId'];
          return ArtistPage(browseId: browseId as String);
        },
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/playlist',
        builder: (context, state) {
          final playlistId =
              (state.extra as Map<String, dynamic>)['playlistId'];
          return OnlinePlaylistPage(playlistId: playlistId as String);
        },
      ),
    ],
  ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExplorePage(),
        ),
      ],
    ),
    // --- Phase 4 - account pages ---
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/account',
          builder: (context, state) => const AccountPage(),
        ),
      ],
    ),
  ];

class MyPageView extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const MyPageView(
      {super.key, required this.currentIndex, required this.children});

  @override
  MyPageViewState createState() => MyPageViewState();
}

class MyPageViewState extends State<MyPageView> {
  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps every branch alive and switches instantly: no
    // PageController animation, no off-screen scroll work, no tab jank.
    final index = widget.currentIndex.clamp(0, widget.children.length - 1);
    return IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          RepaintBoundary(key: ValueKey('page-$i'), child: widget.children[i]),
      ],
    );
  }
}
