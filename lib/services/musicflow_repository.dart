/// Port of Android `musicflow/MusicFlowRepository.kt` — seeds + radio cursor.
///
/// Desktop sources (differences from Android, see plan):
///  - NOW_PLAYING ← `MediaPlayer.currentSongNotifier`
///  - HISTORY ← Hive box `SONG_HISTORY`
///  - CATALOG ← `YTMusic.browse('FEmusic_home')` sections
///  - LIKED ← liked-playlist fallback, offline/quickspicks TODO.
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

import 'musicflow_ranking.dart';
import 'musicflow_session.dart';
import '../utils/playable.dart';

class MusicFlowSignals {
  MusicFlowSignals({this.filter = const MusicFlowCandidateFilter(), this.likedArtists = const {}});

  final MusicFlowCandidateFilter filter;
  final Set<String> likedArtists;
}

class MusicFlowCursor {
  MusicFlowCursor({this.hasMore = true, this.nextFn});

  final bool Function()? hasMoreFn;
  final bool hasMore;
  final Future<List<MusicFlowItem>> Function() nextFn;
}

class MusicFlowRepository {
  MusicFlowRepository({required YTMusic client}) : _client = client;

  final YTMusic _client;

  MusicFlowSignals signals() {
    final recent = hiveRecentSongIds();
    return MusicFlowSignals(
      filter: MusicFlowCandidateFilter(
        recentSongIds: recent,
      ),
      likedArtists: const {}, // TODO: liked artist keys from LibraryService
    );
  }

  Set<String> hiveRecentSongIds() {
    final box = Hive.box('SONG_HISTORY');
    return box.keys.map((k) => k.toString()).take(30).toSet();
  }

  MusicFlowCursor open(MusicFlowItem? nowPlaying) => _RadioCursor(_client, nowPlaying);

  Future<List<MusicFlowItem>> offlineCandidates() async => [];

  Future<List<MusicFlowItem>> catalogSeeds() async {
    final response = await _client.browse(body: {'browseId': 'FEmusic_home'}, limit: 2);
    final sections = response['sections'] as List<dynamic>? ?? [];
    final items = <MusicFlowItem>[];
    for (final section in sections) {
      final contents = (section['contents'] as List?) ?? const [];
      for (final c in contents) {
        final tag = toPlaySong(Map<String, dynamic>.from(c));
        final videoId = tag['videoId'];
        if (videoId != null) {
          items.add(MusicFlowItem(MusicFlowSource.catalog, videoId, primaryArtistKey: (tag['artists'] as List?)?.first?['name']));
        }
      }
    }
    return items;
  }
}

class _RadioCursor extends MusicFlowCursor {
  _RadioCursor(this._client, this._nowPlaying);

  final YTMusic _client;
  final MusicFlowItem? _nowPlaying;
  bool _started = false;

  @override
  late final MusicFlowCursor _delegate = MusicFlowCursor(nextFn: () => _next());

  @override
  Future<List<MusicFlowItem>> next() => _next();

  Future<List<MusicFlowItem>> _next() async {
    if (!_started) {
      _started = true;
      final nowPlaying = _nowPlaying;
      if (nowPlaying != null) {
        return [nowPlaying];
      }
      return (await _client.browse(body: {'browseId': 'FEmusic_home'}, limit: 2)['sections'] as List<dynamic>? ?? [])
          .expand((section) => (section['contents'] as List?) ?? const [])
          .map((c) => MusicFlowItem(MusicFlowSource.catalog, (toPlaySong(Map<String, dynamic>.from(c)))['videoId'] ?? '', primaryArtistKey: null))
          .where((i) => i.songId.isNotEmpty)
          .take(12)
          .toList();
    }
    return [];
  }
}
