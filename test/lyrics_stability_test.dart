import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('lyrics fetch ignores stale results from the previous track', () {
    final box = src('lib/screens/player/widgets/lyrics_box.dart');
    expect(box, contains('int _fetchGeneration = 0'));
    expect(box, contains('final generation = ++_fetchGeneration'));
    expect(box, contains('generation != _fetchGeneration'));
    expect(box, contains('if (!mounted || generation != _fetchGeneration) return;'));
  });

  test('player keeps a single stable LyricsBox instance', () {
    final page = src('lib/screens/player/player_page.dart');
    expect('LyricsBox('.allMatches(page).length, 1);
    expect(page, isNot(contains('Offstage(')));
  });

  test('synced lyrics geometry does not animate with the active line', () {
    final box = src('lib/screens/player/widgets/lyrics_box.dart');
    expect(box, isNot(contains('AnimatedDefaultTextStyle')));
    expect(box, isNot(contains('isCurrent ? 38 : 28')));
    expect(box, contains('const baseSize = 32.0'));
    expect(box, contains('Only the active line rebuilds on the glow tick'));
  });
}
