import 'beat_analysis.dart';

/// Camelot wheel notation: numbers 1-12, A = minor, B = major.
class CamelotKey {
  const CamelotKey(this.number, this.letter);

  final int number; // 1..12
  final String letter; // 'A' or 'B'

  String get code => '$number$letter';

  @override
  String toString() => code;

  @override
  bool operator ==(Object other) =>
      other is CamelotKey && other.number == number && other.letter == letter;

  @override
  int get hashCode => Object.hash(number, letter);
}

/// Maps chroma (0=C ... 11=B) + mode to the standard Camelot wheel:
/// 1A=E minor ... 12A=A minor, 1B=G major ... 12B=C major.
CamelotKey? camelotFor(BeatAnalysisResult beat) {
  final pc = beat.keyPitchClass;
  if (pc == null) return null;
  final minorOrder = [4, 11, 6, 1, 8, 3, 10, 5, 0, 7, 2, 9]; // E B F# C# G# D# A# F C G D A
  final majorOrder = [7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5, 0]; // G D A E B F# C# Ab Eb Bb F C
  final order = beat.keyIsMinor == true ? minorOrder : majorOrder;
  final index = order.indexOf(pc.clamp(0, 11));
  if (index < 0) return null;
  return CamelotKey(index + 1, beat.keyIsMinor == true ? 'A' : 'B');
}

extension BeatHarmonyX on BeatAnalysisResult {
  String? get camelotCode => camelotFor(this)?.code;
}

/// Harmonic compatibility for a transition [from] -> [to].
/// 1.0 same key, 0.85 relative major/minor (same number, letter swap),
/// 0.7 adjacent on the wheel (perfect fifth), 0 otherwise.
double harmonicScore(CamelotKey? from, CamelotKey? to) {
  if (from == null || to == null) return 0;
  if (from == to) return 1.0;
  if (from.number == to.number) return 0.85;
  final delta = (to.number - from.number).abs();
  if (from.letter == to.letter && (delta == 1 || delta == 11)) return 0.7;
  return 0;
}

/// Picks the harmonically best candidate index. Ties prefer the closest to
/// the naturally next track, so the queue is perturbed as little as possible.
int pickHarmonicNext({
  required int nextIndex,
  required List<int> candidateIndices,
  required CamelotKey? from,
  required Map<int, CamelotKey?> keys,
}) {
  var best = nextIndex;
  var bestScore = -1.0;
  for (final index in candidateIndices) {
    final score = harmonicScore(from, keys[index]);
    final tieBreak = -(index - nextIndex).abs() / 1000.0;
    final total = score + tieBreak;
    if (total > bestScore) {
      bestScore = total;
      best = index;
    }
  }
  return best;
}
