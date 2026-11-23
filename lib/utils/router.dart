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
import 'package:Echo/screens/library/history/history_detail_page.dart';
import 'package:Echo/screens/library/library_page.dart';
import 'package:Echo/screens/library/playlist/playlist_details_page.dart';
import 'package:Echo/screens/library/collections/library_collections_page.dart';
import 'package:Echo/screens/library/local_songs/local_songs_page.dart';
import 'package:Echo/screens/library/ytm_library_page.dart';
import 'package:Echo/screens/library/collections/library_song_list_page.dart';
import 'package:Echo/screens/player/player_page.dart';
import 'package:Echo/screens/search/search_page.dart';
import 'package:Echo/screens/search/local_search_page.dart';
import 'package:Echo/screens/settings/about/about_page.dart';
import 'package:Echo/screens/settings/ai/ai_hub_page.dart';
import 'package:Echo/screens/settings/ai/echo_brain_page.dart';
import 'package:Echo/screens/settings/appearance/appearance_page.dart';
import 'package:Echo/screens/settings/appearance/appearance_details_page.dart';
import 'package:Echo/screens/coming_soon/coming_soon_page.dart';
import 'package:Echo/screens/coming_soon/coming_soon_catalog.dart';
import 'package:Echo/screens/explore/music_flow_feed_page.dart';
import 'package:Echo/screens/player/ambient_page.dart';
import 'package:Echo/screens/settings/export_queue_page.dart';
import 'package:Echo/screens/settings/integrations/integration_page.dart';
import 'package:Echo/screens/settings/integrations/integration_catalog.dart';

import 'package:Echo/screens/settings/backup_storage/backup_storage_page.dart';
import 'package:Echo/screens/settings/content/content_page.dart';
import 'package:Echo/screens/settings/content/content_filter_page.dart';
import 'package:Echo/screens/settings/player/equalizer/equalizer_page.dart';
import 'package:Echo/screens/settings/player/equalizer/axion_eq_page.dart';
import 'package:Echo/screens/settings/music_flow_settings_page.dart';
import 'package:Echo/screens/settings/update_settings_page.dart';
import 'package:Echo/screens/settings/player/player_settings_page.dart';
import 'package:Echo/screens/settings/player/automix_debug_page.dart';
import 'package:Echo/screens/settings/privacy/privacy_page.dart';
import 'package:Echo/screens/settings/stats/listening_summary_page.dart';
import 'package:Echo/screens/settings/stats/wrapped_page.dart';
import 'package:Echo/screens/settings/stats/wrapped_stories_page.dart';
import 'package:Echo/screens/settings/storage/storage_page.dart';
import 'package:Echo/screens/settings/services/yt_music/yt_music_page.dart';
import 'package:Echo/screens/settings/services/spotify/spotify_import_page.dart';
import 'package:Echo/screens/settings/settings_page.dart';
import 'package:Echo/screens/detail/album_page.dart';
import 'package:Echo/screens/detail/artist_page.dart';
import 'package:Echo/screens/detail/playlist_page.dart';
import 'package:Echo/screens/account/account_page.dart';
import 'package:Echo/screens/account/device_link_page.dart';
import 'package:Echo/utils/page_transitions.dart';
import 'package:Echo/screens/connect/cast_page.dart';
import 'package:Echo/screens/connect/cast_session_page.dart';
import 'package:Echo/screens/explore/explore_page.dart';
import 'package:Echo/screens/login/login_page.dart';
import 'package:Echo/screens/shell/app_shell.dart';

EchoPage<dynamic> _softPage(GoRouterState state, Widget child) =>
    EchoPage<dynamic>(key: state.pageKey, child: child);

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
    // Device/Cast pages live inside the Settings shell branch (see `branches`)
    // so the navigation bar stays visible and highlights the right tab.
    // Real Podcasts home via YouTube Music's public podcasts browse endpoint.
    GoRoute(
      path: '/podcasts',
      builder: (context, state) => const ChipPage(
        title: 'Podcasts',
        endpoint: {'browseId': 'FEmusic_podcasts'},
      ),
    ),
    // Reachable "coming in a future update" placeholder routes for the
    // mobile features that have no desktop implementation.
    // Real vertical-swipe Music Flow feed.
    GoRoute(
      path: '/music_flow_full',
      builder: (context, state) => const MusicFlowFeedPage(),
    ),
    // Real Canvas / Ambient immersive player.
    GoRoute(
      path: '/canvas_ambient',
      builder: (context, state) => const AmbientPage(),
    ),
    // Real Export-as-MP3 task queue.
    GoRoute(
      path: '/export_queue',
      builder: (context, state) => const ExportQueuePage(),
    ),
    // Real integration settings screens with persisted local config.
    for (final integration in IntegrationCatalog.screens)
      GoRoute(
        path: '/${integration.route}',
        builder: (context, state) => IntegrationPage(screen: integration),
      ),
    for (final feature in ComingSoonCatalog.features)
      GoRoute(
        path: '/${feature.route}',
        builder: (context, state) => ComingSoonPage(
          title: feature.title,
          feature: feature.message,
        ),
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
                final args = state.extra as Map<String, dynamic>? ?? {};
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
      // Detail pages stay inside the Home branch: navigating to an album or
      // artist must not switch the highlighted tab or rebuild another branch.
      GoRoute(
        path: '/album',
        pageBuilder: (context, state) => _softPage(
          state,
          AlbumPage(
            browseId: ((state.extra as Map<String, dynamic>? ?? {})['browseId'])
                    ?.toString() ??
                '',
          ),
        ),
      ),
      GoRoute(
        path: '/artist',
        pageBuilder: (context, state) => _softPage(
          state,
          ArtistPage(
            browseId: ((state.extra as Map<String, dynamic>? ?? {})['browseId'])
                    ?.toString() ??
                '',
          ),
        ),
      ),
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
        routes: [
          GoRoute(
            path: 'local',
            builder: (context, state) => const LocalSearchPage(),
          ),
        ],
      ),
    ],
  ),
  // Android's fifth navigation tab.
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/explore',
        pageBuilder: (context, state) =>
            _softPage(state, const ExplorePage()),
        routes: [
          GoRoute(
            path: 'new_releases',
            pageBuilder: (context, state) => _softPage(
              state,
              const ChipPage(
                title: 'New releases',
                endpoint: {'browseId': 'FEmusic_new_releases_albums'},
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  StatefulShellBranch(routes: [
    GoRoute(
      path: '/saved',
      builder: (context, state) => const YtmLibraryPage(),
      routes: [
        GoRoute(
          path: 'local',
          builder: (context, state) => const LibraryPage(),
        ),
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
                final args = state.extra as Map<String, dynamic>? ?? {};
                return DownloadPlaylistPage(
                  playlistId: args['playlistId']?.toString() ?? '',
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
          path: 'history_detail',
          builder: (context, state) => const HistoryDetailPage(),
        ),
        GoRoute(
          path: 'library_songs',
          builder: (context, state) =>
              LibraryCollectionsPage(initialTab: (state.extra as int?) ?? 0),
        ),
        GoRoute(
          path: 'local_songs',
          builder: (context, state) => const LocalSongsPage(),
        ),
        GoRoute(
          path: 'library_song_list',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return LibrarySongListPage(
              songs: (args['songs'] as List?) ?? const [],
              title: args['title'] as String?,
            );
          },
        ),
        GoRoute(
          path: 'playlist_details',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return PlaylistDetailsPage(
              playlistkey: args['playlistkey']?.toString() ?? '',
            );
          },
        ),
      ],
    ),
    // Online library and playlists live under the Library tab.
    GoRoute(
      path: '/ytm_library',
      pageBuilder: (context, state) =>
          _softPage(state, const YtmLibraryPage()),
    ),
    GoRoute(
      path: '/playlist',
      pageBuilder: (context, state) => _softPage(
        state,
        OnlinePlaylistPage(
          playlistId: ((state.extra as Map<String, dynamic>? ?? {})['playlistId'])
                  ?.toString() ??
              '',
        ),
      ),
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
            routes: [
              GoRoute(
                path: 'details',
                builder: (context, state) => const AppearanceDetailsPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'ai',
            builder: (context, state) => const AiHubPage(),
            routes: [
              GoRoute(
                path: 'brain',
                builder: (context, state) => const EchoBrainPage(),
              ),
            ],
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
            path: 'music_flow',
            pageBuilder: (context, state) =>
                _softPage(state, const MusicFlowSettingsPage()),
          ),
          GoRoute(
            path: 'update',
            pageBuilder: (context, state) =>
                _softPage(state, const UpdateSettingsPage()),
          ),
          GoRoute(
              path: 'player',
              builder: (context, state) => const PlayerSettingsPage(),
              routes: [
                GoRoute(
                  path: 'equalizer',
                  builder: (context, state) => const EqualizerPage(),
                ),
                GoRoute(
                  path: 'axion',
                  builder: (context, state) => const AxionEqPage(),
                ),
                GoRoute(
                  path: 'automix_debug',
                  builder: (context, state) => const AutomixDebugPage(),
                ),
              ]),
          GoRoute(
            path: 'services/ytmusic',
            builder: (context, state) => const YTMusicPage(),
          ),
          GoRoute(
            path: 'services/spotify_import',
            builder: (context, state) => const SpotifyImportPage(),
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
            path: 'storage',
            builder: (context, state) => const StoragePage(),
          ),
          GoRoute(
            path: 'listening_summary',
            builder: (context, state) => const ListeningSummaryPage(),
          ),
          GoRoute(
            path: 'wrapped',
            builder: (context, state) => const WrappedStoriesPage(),
          ),
          GoRoute(
            path: 'content',
            builder: (context, state) => const ContentPage(),
            routes: [
              GoRoute(
                path: 'blocked_artists',
                builder: (context, state) => const ContentFilterPage(mode: 'artists'),
              ),
              GoRoute(
                path: 'disliked_songs',
                builder: (context, state) => const ContentFilterPage(mode: 'songs'),
              ),
            ],
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutPage(),
          ),
        ]),
      // Account + device pages belong to the Settings tab: going back from
      // them must return to Settings, not to an unrelated branch.
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) =>
            _softPage(state, const AccountPage()),
      ),
      GoRoute(
        path: '/device_link',
        pageBuilder: (context, state) =>
            _softPage(state, const DeviceLinkPage()),
      ),
      GoRoute(
        path: '/cast',
        pageBuilder: (context, state) => _softPage(state, const CastPage()),
        routes: [
          GoRoute(
            path: 'session',
            pageBuilder: (context, state) =>
                _softPage(state, const CastSessionPage()),
          ),
        ],
      ),
  ]),
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
