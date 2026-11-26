/// Port of Android `musicflow/MusicFlowSession.kt` — the paged feed
/// (`start`/`loadMore` semantics: append-only pages, cursor over seeds).
/// The seed/fetch pipeline (`MusicFlowRepository.RadioCursor`) is reduced to
/// a pluggable `fetchSeeds` callback.
import 'package:Echo/services/musicflow_ranking.dart';
import 'package:Echo/services/musicflow_queue.dart';

class MusicFlowFeedState {
  const MusicFlowFeedState({
    this.items = const [],
    this.selectedIndex = 0,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.isOffline = false,
  });

  final List<MusicFlowItem> items;
  final int selectedIndex;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final bool isOffline;

  String? get selectedSongId => items.isEmpty ? null : items[selectedIndex].songId;
}

enum MusicFlowFeedError { offline, empty, failed }

class MusicFlowSession {
  static const INITIAL_TARGET = 12;
  static const MAX_FETCHES_PER_LOAD = 3;
  static const MAX_FEED_SIZE = 300;

  final MusicFlowRankingConfig rankingConfig = MusicFlowRankingConfig();

  MusicFlowFeedState _state = const MusicFlowFeedState();
  MusicFlowFeedState get state => _state;
  List<MusicFlowItem> get items => _state.items;
  int get selectedIndex => _state.selectedIndex;
  String? get currentSelectedId => _state.selectedSongId;
  bool get isInitialLoading => _state.isInitialLoading;
  bool get isLoadingMore => _state.isLoadingMore;
  String? get error => _state.error;
  bool get hasMore => _state.hasMore;
  bool get isOffline => _state.isOffline;
  bool get isStarted => _state.items.isNotEmpty;

  /// Seed queue for this session (Android: `MusicFlowRepository`
  /// seeds + radio cursor). Replaced by the repository port later.
  List<MusicFlowItem> Function() fetchSeeds = () => [];
  /// Current feed tail for artist spacing (set by callers).
  List<String?> feedTailArtists = const [];
  Set<String> likedArtists = const {};
  Set<String> lessLikeArtists = const {};
  Set<String> seenSongIds = {};
  Set<String> seenTrackKeys = {};

  void reset() {
    seenSongIds.clear();
    seenTrackKeys.clear();
    _state = const MusicFlowFeedState(hasMore: true);
    loadMore();
  }

  Future<void> loadMore() async {
    while (_state.items.length < INITIAL_TARGET &&
        _state.hasMore &&
        _state.items.length < MAX_FEED_SIZE) {
      final before = _state.items.length;
      final batch = fetchSeeds();
      if (batch.isEmpty) break;
      final ranked = rankMusicFlowCandidates(
        batch,
        feedTailArtists: feedTailArtists,
        likedArtists: likedArtists,
        lessLikeArtists: lessLikeArtists,
        config: rankingConfig,
      );
      final appended = ranked
          .where((i) => seenSongIds.add(i.songId))
          .toList();
      if (appended.isEmpty) break;
      _state = MusicFlowFeedState(
        items: List<MusicFlowItem>.of(_state.items)..addAll(appended),
        hasMore: false,
        isOffline: false,
      );
      if (_state.items.length == before) break;
    }
  }

  void select(int index) {
    _state = MusicFlowFeedState(
      items: _state.items,
      selectedIndex: index.clamp(0, _state.items.isEmpty ? 0 : _state.items.length - 1),
      hasMore: _state.hasMore,
      isOffline: _state.isOffline,
    );
  }

  int indexOf(String? songId) {
    if (songId == null) return -1;
    return _state.items.indexWhere((i) => i.songId == songId);
  }

  void hide(String songId) => seenSongIds.add(songId);
  void lessLikeThis(String artistKey) => lessLikeArtists.add(artistKey);

  MusicFlowQueue get queue => MusicFlowQueue(session: this, title: 'Music Flow');
}
