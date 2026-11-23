import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/beat_analysis.dart';
import 'package:Echo/services/harmonic_mixing.dart';

BeatAnalysisResult key(int pc, bool minor) => BeatAnalysisResult(
      bpm: 120,
      firstBeatOffsetMs: 0,
      confidence: 1,
      keyPitchClass: pc,
      keyIsMinor: minor,
    );

void main() {
  test('maps the standard Camelot wheel', () {
    expect(key(9, true).camelotCode, '12A'); // A minor
    expect(key(0, false).camelotCode, '12B'); // C major
    expect(key(4, true).camelotCode, '1A'); // E minor
    expect(key(7, false).camelotCode, '1B'); // G major
    expect(key(8, true).camelotCode, '5A'); // G# minor
    expect(key(11, false).camelotCode, '5B'); // B major
  });

  test('scores same key highest, then relative and perfect fifth', () {
    final a = camelotFor(key(9, true))!; // 12A
    final same = camelotFor(key(9, true))!;
    final relative = camelotFor(key(0, false))!; // 12B
    final fifth = camelotFor(key(2, true))!; // 11A (D minor)
    final far = camelotFor(key(6, false))!; // 6B
    expect(harmonicScore(a, same), 1.0);
    expect(harmonicScore(a, relative), 0.85);
    expect(harmonicScore(a, fifth), 0.7); // 12A -> 11A (adjacent)
    expect(harmonicScore(a, far), 0);
  });

  test('picks the compatible candidate and keeps order as tie-break', () {
    final from = camelotFor(key(9, true));
    final keys = <int, CamelotKey?>{
      1: camelotFor(key(6, false)), // incompatible
      2: camelotFor(key(2, true)), // 11A, compatible
      3: camelotFor(key(9, true)), // 12A, perfect match
    };
    expect(
      pickHarmonicNext(
        nextIndex: 1,
        candidateIndices: [1, 2, 3],
        from: from,
        keys: keys,
      ),
      3,
    );
    // Equal score: nearest to the natural next index wins.
    expect(
      pickHarmonicNext(
        nextIndex: 1,
        candidateIndices: [1, 2],
        from: null,
        keys: {1: null, 2: null},
      ),
      1,
    );
  });
}
