import 'package:bloc/bloc.dart';
import 'package:Echo/ytmusic/ytmusic.dart';
import 'package:Echo/services/account_refresh.dart';
import 'package:Echo/services/charts_service.dart';
import 'package:Echo/services/chart_model.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/home_sections.dart';
import 'package:Echo/utils/safe_cast.dart';
import 'package:meta/meta.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final YTMusic _ytMusic;
  HomeCubit(this._ytMusic) : super(HomeLoading()) {
    // Re-fetch with fresh credentials when the account changes (login).
    accountEpoch.addListener(_onAccountChanged);
  }

  void _onAccountChanged() => fetch();

  @override
  Future<void> close() {
    accountEpoch.removeListener(_onAccountChanged);
    return super.close();
  }

  /// Build the home screen from the user's [HomeSectionsConfig] order.
  /// Disabled sections are not fetched at all (no needless network calls).
  Future<void> fetch() async {
    emit(const HomeLoading());
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

      final feed = results[0] as Map<String, dynamic>;
      final charts = results[1] as List<ChartURL>;
      final liked = results[2] as Map;
      final playlists = results[3] as Map;

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
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Future<void> refresh() => fetch();

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
