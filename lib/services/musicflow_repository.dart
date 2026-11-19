/// Port of Android `musicflow/MusicFlowRepository.kt` — seeds + radio cursor.
/// Desktop equivalents: NOW_PLAYING ← `MediaPlayer` current song; CATALOG ←
/// `YTMusic.getNextSongList` (radio); LIKED/HISTORY/QUICKPICKS TODO (returned
/// by `signals()` as empty).
import 'package:get_it/get_it.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/musicflow_ranking.dart';
import 'package:Echo/services/playable.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

class MusicFlowSignals {
  const MusicFlowSignals({
    this.filter = const MusicFlowCandidateFilter(),
    this.likedArtists = const {},
  });

  final MusicFlowCandidateFilter filter;
  final Set<String> likedArtists;
}

class MusicFlowCursor {
  const MusicFlowCursor({required this.hasMore, required this.next});

  final bool hasMore;
  final Future<List<MusicFlowItem>> Function() next;
}

class MusicFlowRepository {
  MusicFlowRepository({required YTMusic client}) : _client = client;

  final YTMusic _client;

  MusicFlowSignals signals() => const MusicFlowSignals();

  MusicFlowCursor open(String? nowPlayingId) =>
      _RadioCursor(nowPlayingId, _client);
}

class _RadioCursor implements MusicFlowCursor {
  _RadioCursor(this._nowPlayingId, this._client);

  final String? _nowPlayingId;
  final YTMusic _client;
  bool _started = false;

  @override
  final bool hasMore = true;

  @override
  Future<List<MusicFlowItem>> next() async {
    if (!_started) {
      _started = true;
      final id = _nowPlayingId;
      if (id != null && id.isNotEmpty) {
        return [
          MusicFlowItem(MusicFlowSource.nowPlaying, id, primaryArtistKey: null),
        ];
      }
    }
    // Desktop: the radio/automix stream is the InnerTube "next" queue
    // (Android uses `YouTube.next` with an RDAMVM playlistId).
    final mp = GetIt.I<MediaPlayer>();
    final songs = await _client.getNextSongList(
      videoId: mp.currentSongNotifier.value?.id,
    );
    return toPlaySongs(songs).map((s) {
      final artists = s['artists'];
      return MusicFlowItem(
        MusicFlowSource.catalog,
        s['videoId'] as String? ?? '',
        primaryArtistKey: (artists is List && artists.isNotEmpty) ? (artists.first['name'] as String?) : null,
      );
    }).where((i) => i.songId.isNotEmpty).toList();
  }
}
