import 'package:Echo/services/lyrics_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtmlParser', () {
    test('parses line timings', () {
      expect(TtmlParser.parseTime('00:12.34'), closeTo(12.34, 0.01));
      expect(TtmlParser.parseTime('01:02:03.5'), closeTo(3723.5, 0.01));
      expect(TtmlParser.parseTime('5.2'), closeTo(5.2, 0.01));
    });

    test('converts TTML line + word spans to LRC', () {
      final ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml">
<body><div>
<p begin="00:01.00" end="00:03.00">
<span begin="00:01.00" end="00:01.50">Hello </span>
<span begin="00:01.50" end="00:02.00">world</span>
</p>
</div></body></tt>''';
      final lrc = TtmlParser.toLrc(ttml);
      expect(lrc, contains('[00:01.00]Hello world'));
      expect(lrc, contains('<Hello:1.0:1.5|world:1.5:2.0>'));
    });
  });

  group('SimpMusicProvider.pick', () {
    test('prefers the track closest to the requested duration', () {
      final best = SimpMusicProvider.pick([
        {'duration': 100, 'syncedLyrics': 'A'},
        {'duration': 205, 'syncedLyrics': 'B'},
      ], 200);
      expect(best?['duration'], 205);
    });

    test('rejects tracks outside the 10s tolerance', () {
      expect(SimpMusicProvider.pick([
        {'duration': 100, 'syncedLyrics': 'A'},
      ], 200), isNull);
    });
  });

  group('YouLyPlusProvider.convertSyllabus', () {
    test('builds word-timestamps from syllable data', () {
      final lrc = YouLyPlusProvider.convertSyllabus([
        {
          'time': 1000,
          'syllabus': [
            {'text': 'Hel', 'time': 1000},
            {'text': 'lo ', 'time': 1200},
            {'text': 'world', 'time': 1400},
          ],
        },
      ]);
      expect(lrc, contains('<00:01.000>Hel'));
      expect(lrc, contains('world'));
    });

    test('falls back to plain text', () {
      expect(YouLyPlusProvider.convertSyllabus([
        {'time': 500, 'text': 'hello'},
      ]), contains('hello'));
    });
  });

  group('PaxsenixProvider.scoreAndFilter', () {
    test('scores title/duration/artist matches above mismatches', () {
      final scored = PaxsenixProvider.scoreAndFilter(
        [
          {'displayName': 'Song', 'displayArtist': 'Artist', 'duration': 200000, 'id': '1'},
          {'displayName': 'Other', 'displayArtist': 'Someone', 'duration': 600000, 'id': '2'},
        ],
        'Song',
        'Artist',
        200,
      );
      expect(scored.isNotEmpty, isTrue);
      expect(scored.first['result']['id'], '1');
    });
  });

  group('KuGouProvider', () {
    test('normalizeTitle strips parentheticals/brackets', () {
      expect(KuGouProvider.normalizeTitle('Song (Live) [Remix]').trim(), 'Song');
    });

    test('normalize drops metadata lines', () {
      final out = KuGouProvider.normalize('作词: someone\n[00:01.00]First line\n[00:02.00]Second');
      expect(out, contains('[00:01.00]First line'));
      expect(out, isNot(contains('作词')));
    });
  });
}
