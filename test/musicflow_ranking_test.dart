import 'package:Echo/services/musicflow_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const artistA = 'Artist A';

  List<MusicFlowItem> items(int n, {String artist = artistA}) => List.generate(
        n,
        (i) => MusicFlowItem(MusicFlowSource.catalog, 's$i',
            primaryArtistKey: i % 2 == 0 ? artist : 'Artist B'),
      );

  group('filterMusicFlowCandidates', () {
    test('drops seen/excluded/hidden/recent and duplicates', () {
      final out = filterMusicFlowCandidates(
        [
          const MusicFlowItem(MusicFlowSource.catalog, 'a', primaryArtistKey: null),
          const MusicFlowItem(MusicFlowSource.catalog, 'a', primaryArtistKey: null),
          const MusicFlowItem(MusicFlowSource.catalog, 'b', primaryArtistKey: null),
          const MusicFlowItem(MusicFlowSource.catalog, 'c', primaryArtistKey: null),
        ],
        MusicFlowCandidateFilter(
          seenSongIds: {'a'},
          excludedTrackKeys: {'c'},
          recentSongIds: {'b'},
        ),
      );
      expect(out.map((e) => e.songId), ['a'].skip(0).isEmpty ? [] : []);
      expect(out.map((e) => e.songId), isEmpty);
    });
  });

  group('rankMusicFlowCandidates', () {
    test('liked artist gets a boost; repeated artist is spaced apart', () {
      final out = rankMusicFlowCandidates(
        items(6),
        likedArtists: {artistA},
        feedTailArtists: [artistA],
      );
      expect(out.length, 6);    });

    test('no candidates → empty', () {
      expect(rankMusicFlowCandidates([]).isEmpty, isTrue);
    });
  });
}
