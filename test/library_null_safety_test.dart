import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/ytmusic/helpers.dart';

void main() {
  group('firstMapOrEmpty (library response null-safety)', () {
    test('returns the first renderer that exists', () {
      final response = {
        'contents': {
          'itemSectionRenderer': {'items': []},
        },
      };
      final result = firstMapOrEmpty(response, [
        ['contents', 'gridRenderer'],
        ['contents', 'itemSectionRenderer'],
      ]);
      expect(result, {'items': []});
    });

    test('returns an empty map instead of throwing when nothing matches', () {
      // This is the case that used to throw
      // "type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'".
      final result = firstMapOrEmpty(const <String, dynamic>{}, [
        ['contents', 'gridRenderer'],
        ['contents', 'itemSectionRenderer'],
      ]);
      expect(result, isEmpty);
      expect(result, isA<Map>());
    });

    test('ignores paths that resolve to non-map values', () {
      final response = {
        'contents': {'gridRenderer': 'not-a-map'},
      };
      final result = firstMapOrEmpty(response, [
        ['contents', 'gridRenderer'],
        ['contents', 'fallback'],
      ]);
      expect(result, isEmpty);
    });
  });

  test('library mixin no longer assigns a possibly-null result to Map', () {
    final lib = File('lib/ytmusic/mixins/library.dart').readAsStringSync();
    expect(lib, isNot(contains('outerContents = outerContents =')),
        reason: 'duplicate assignment typo must stay fixed');
    expect(lib, contains('firstMapOrEmpty(contents,'));

    final home =
        File('lib/screens/home/cubit/home_cubit.dart').readAsStringSync();
    expect(home, contains('results[2] is Map'));
    expect(home, contains('results[3] is Map'));
    expect(home, contains('ErrorLog.write'));
  });
}
