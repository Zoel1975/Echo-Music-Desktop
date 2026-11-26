import 'package:bloc/bloc.dart';
import 'package:Echo/ytmusic/ytmusic.dart';
import 'package:Echo/services/account_refresh.dart';
import 'package:Echo/services/charts_service.dart';
import 'package:Echo/services/chart_model.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/error_log.dart';
import 'package:Echo/services/home_sections.dart';
import 'package:Echo/utils/safe_cast.dart';
import 'package:meta/meta.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final YTMusic _ytMusic;
  /// Last emitted state, exposed for runtime diagnostics of the rendered home.
  static HomeState? lastState;

  HomeCubit(this._ytMusic) : super(HomeLoading()) {
    // Re-fetch with fresh credentials when the account changes (login).
    accountEpoch.addListener(_onAccountChanged);
    HomeSectionsConfig.onChange = refresh;
  }

  @override
  void emit(HomeState state) {
    // A slow home fetch can finish after the cubit was closed (app shutdown).
    if (isClosed) return;
    lastState = state;
    super.emit(state);
  }

  // Keep the current content on screen while reloading: a full HomeLoading
  // caused the home to flash empty and reset the scroll position.
  void _onAccountChanged() => fetch(silent: true);

  @override
  Future<void> close() {
    accountEpoch.removeListener(_onAccountChanged);
    if (HomeSectionsConfig.onChange == refresh) HomeSectionsConfig.onChange = null;
    return super.close();
  }

  /// Build the home screen from the user's [HomeSectionsConfig] order.
  /// Disabled sections are not fetched at all (no needless network calls).
  Future<void> fetch({bool silent = false}) async {
    if (!silent || state is! HomeSuccess) emit(const HomeLoading());
    try {
      final config = HomeSectionsConfig.load();
      final enabled = config.order.toSet();
      final signedIn = CookieStore.instance.cookieHeader != null;

      final results = await Future.wait([
        enabled.contains(HomeSectionKind.feed)
            ? _ytMusic.browse()
            : Future<Map<String, dynamic>>.value(<String, dynamic>{}),
        enabled.contains(HomeSectionKind.charts)
            ? ChartsService().getChartsWithPreviews()
            : Future<List<ChartURL>>.value(<ChartURL>[]),
        enabled.contains(HomeSectionKind.likedSongs) && signedIn
            ? _ytMusic.getLibrarySongs()
            : Future<Map>.value(<String, dynamic>{}),
        enabled.contains(HomeSectionKind.playlists) && signedIn
            ? _ytMusic.getLibraryPlaylists()
            : Future<Map>.value(<String, dynamic>{}),
      ]);

      // Never hard-cast here: a null/empty response from any of the four
      // endpoints used to surface as "type 'Null' is not a subtype of
      // type 'Map<dynamic, dynamic>'" on the Home screen.
      final feed = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : <String, dynamic>{};
      final charts =
          results[1] is List<ChartURL> ? results[1] as List<ChartURL> : <ChartURL>[];
      final liked = results[2] is Map ? results[2] as Map : const {};
      final playlists = results[3] is Map ? results[3] as Map : const {};

      final likedItems = safeMapList(liked['contents']);
      final playlistItems = safeMapList(playlists['contents']);
      final built = <HomeSectionKind, List<dynamic>>{
        HomeSectionKind.feed: safeMapList(feed['sections']),
        HomeSectionKind.charts: [_createChartsSection(charts)],
        HomeSectionKind.likedSongs: likedItems.isEmpty
            ? const []
            : [
                {
                  'title': 'Brani preferiti',
                  'contents': likedItems,
                }
              ],
        HomeSectionKind.playlists: playlistItems.isEmpty
            ? const []
            : [
                {
                  'title': 'Le tue playlist',
                  'contents': playlistItems,
                }
              ],
      };

      final sections = <dynamic>[];
      for (final kind in config.order) {
        sections.addAll(built[kind] ?? const []);
      }

      emit(HomeSuccess(
        chips: feed['chips'] ?? [],
        sections: sections,
        continuation: enabled.contains(HomeSectionKind.feed)
            ? feed['continuation']
            : null,
        loadingMore: false,
      ));
    } catch (e, st) {
      ErrorLog.write('Home fetch failed: $e\n$st');
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  /// Pull-to-refresh and home-customization changes reload without wiping
  /// the visible content (and therefore without jumping the scroll position).
  Future<void> refresh() => fetch(silent: true);

  Future<void> fetchNext() async {
    final current = state;
    if (current is! HomeSuccess) return;
    if (current.loadingMore || current.continuation == null) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final feed = await _ytMusic.browseContinuation(
          additionalParams: current.continuation!);
      emit(
        HomeSuccess(
          chips: current.chips,
          sections: [...current.sections, ...feed['sections']],
          continuation: feed['continuation'],
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Map<String, dynamic> _createChartsSection(List<ChartURL> charts) => {
        'title': 'Browse Charts',
        'contents': charts.map((chart) {
          return {
            'title': chart.title,
            'subtitle': 'Billboard Chart',
            'thumbnails': [
              {
                'url': chart.coverArt ??
                    'https://www.billboard.com/wp-content/themes/vip/pmc-billboard-2021/assets/app/icons/icon-512x512.png',
                'width': 500,
                'height': 500
              }
            ],
            'chartUrl': chart,
            'aspectRatio': 1.0,
          };
        }).toList(),
      };
}
