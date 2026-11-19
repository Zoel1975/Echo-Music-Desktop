/// Port of Android `musicflow/MusicFlowModels.kt` + `musicflow/MusicFlowRanking.kt`.
library musicflow_ranking;

/// Android `MusicFlowSource` (`enum class MusicFlowSource`).
enum MusicFlowSource { nowPlaying, history, liked, quickPicks, catalog, offline }

/// Port of Android `MusicFlowItem` (`data class MusicFlowItem`).
class MusicFlowItem {
  const MusicFlowItem(this.source, this.songId, {required this.primaryArtistKey});

  final MusicFlowSource source;
  final String songId;
  final String? primaryArtistKey;
}

/// Port of Android `MusicFlowRankingConfig`.
class MusicFlowRankingConfig {
  const MusicFlowRankingConfig({
    this.artistSpacing = 2,
    this.likedArtistBoost = 1.0,
    this.lessLikeThisPenalty = 2.5,
    this.positionDecay = 0.02,
    this.sourceWeights = const {
      MusicFlowSource.history: 0.6,
      MusicFlowSource.liked: 0.8,
      MusicFlowSource.quickPicks: 0.5,
      MusicFlowSource.catalog: 0.2,
      MusicFlowSource.offline: 0.4,
    },
  });

  final int artistSpacing;
  final double likedArtistBoost;
  final double lessLikeThisPenalty;
  final double positionDecay;
  final Map<MusicFlowSource, double> sourceWeights;
}

/// Port of Android `MusicFlowCandidateFilter`.
class MusicFlowCandidateFilter {
  const MusicFlowCandidateFilter({
    this.seenSongIds = const {},
    this.seenTrackKeys = const {},
    this.excludedTrackKeys = const {},
    this.hiddenSongIds = const {},
    this.recentSongIds = const {},
  });

  final Set<String> seenSongIds;
  final Set<String> seenTrackKeys;
  final Set<String> excludedTrackKeys;
  final Set<String> hiddenSongIds;
  final Set<String> recentSongIds;
}

/// Port of Android `filterMusicFlowCandidates` (uses `songId` as the
/// `trackKeyOf(title, artists)` equivalent for desktop items, which do not
/// carry `SongItem` title/artist lists).
List<MusicFlowItem> filterMusicFlowCandidates(
  List<MusicFlowItem> candidates,
  MusicFlowCandidateFilter filter,
) {
  final batchIds = <String>{};
  final batchKeys = <String>{};
  final result = <MusicFlowItem>[];
  for (final item in candidates) {
    if (item.songId.isEmpty) continue;
    if (!batchIds.add(item.songId)) continue;
    if (!batchKeys.add(item.songId)) continue;
    if (filter.seenSongIds.contains(item.songId)) continue;
    if (filter.seenTrackKeys.contains(item.songId)) continue;
    if (filter.excludedTrackKeys.contains(item.songId)) continue;
    if (filter.hiddenSongIds.contains(item.songId)) continue;
    if (filter.recentSongIds.contains(item.songId)) continue;
    result.add(item);
  }
  return result;
}

/// Port of Android `rankMusicFlowCandidates`: scores by source weight +
/// position decay + liked/less-like-artist deltas, then greedily picks so the
/// same artist is never within `artistSpacing` of itself (incl. feed tail).
List<MusicFlowItem> rankMusicFlowCandidates(
  List<MusicFlowItem> candidates, {
  List<String?> feedTailArtists = const [],
  Set<String> likedArtists = const {},
  Set<String> lessLikeArtists = const {},
  MusicFlowRankingConfig config = const MusicFlowRankingConfig(),
}) {
  final scored = candidates
      .mapIndexed((index, item) {
        final artist = item.primaryArtistKey;
        var score = config.sourceWeights[item.source] ?? 0.0;
        score -= index * config.positionDecay;
        if (artist != null && likedArtists.contains(artist)) {
          score += config.likedArtistBoost;
        }
        if (artist != null && lessLikeArtists.contains(artist)) {
          score -= config.lessLikeThisPenalty;
        }
        return _Scored(item, score);
      })
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  final recent = feedTailArtists.length > config.artistSpacing
      ? List<String?>.of(
          feedTailArtists.sublist(
            feedTailArtists.length - config.artistSpacing,
          ),
        )
      : List<String?>.of(feedTailArtists);

  final result = <MusicFlowItem>[];
  final remaining = List<_Scored>.of(scored);
  while (remaining.isNotEmpty) {
    var pickIndex = 0;
    for (var i = 0; i < remaining.length; i++) {
      final artist = remaining[i].item.primaryArtistKey;
      if (artist == null || !recent.contains(artist)) {
        pickIndex = i;
        break;
      }
    }
    final picked = remaining.removeAt(pickIndex);
    result.add(picked.item);
    recent.add(picked.item.primaryArtistKey);
    while (recent.length > config.artistSpacing) recent.removeAt(0);
  }
  return result;
}

class _Scored {
  const _Scored(this.item, this.score);
  final MusicFlowItem item;
  final double score;
}

extension _MapIndexed<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int, T) f) {
    final out = <R>[];
    for (var i = 0; i < length; i++) {
      out.add(f(i, this[i]));
    }
    return out;
  }
}
