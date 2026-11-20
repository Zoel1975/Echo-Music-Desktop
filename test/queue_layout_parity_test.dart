import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/queue_filter.dart';
import 'package:Echo/services/player_layout.dart';
import 'package:Echo/screens/settings/services/spotify/spotify_import_page.dart';

void main() {
  group('QueueFilter (Android QueueExt / RadioQueuePageFilter)', () {
    test('dedupes by id keeping first', () {
      final items = ['a', 'b', 'a', 'c', 'b'];
      final out = QueueFilter.dedupe(items, (s) => s);
      expect(out, ['a', 'b', 'c']);
    });

    test('searches title and artist case-insensitively', () {
      final items = [
        {'title': 'Harder', 'artist': 'Daft Punk'},
        {'title': 'Yellow', 'artist': 'Coldplay'},
      ];
      expect(
        QueueFilter.search(
          items,
          'daft',
          titleOf: (m) => m['title'].toString(),
          artistOf: (m) => m['artist'].toString(),
        ).length,
        1,
      );
      expect(
        QueueFilter.search(
          items,
          '',
          titleOf: (m) => m['title'].toString(),
        ).length,
        2,
      );
      expect(
        QueueFilter.search(
          items,
          'yellow',
          titleOf: (m) => m['title'].toString(),
        ).first['title'],
        'Yellow',
      );
    });

    test('filters radio items by source', () {
      final items = [
        {'src': 'radio', 'id': 1},
        {'src': 'library', 'id': 2},
      ];
      final out = QueueFilter.bySource(items, 'radio',
          sourceOf: (m) => m['src']?.toString());
      expect(out.length, 1);
      expect(out.first['id'], 1);
    });
  });

  group('PlayerLayoutResolver (3 Android layouts)', () {
    test('resolves compact / narrow / wide', () {
      expect(PlayerLayoutResolver.resolve(400), PlayerLayout.compact);
      expect(PlayerLayoutResolver.resolve(600), PlayerLayout.narrow);
      expect(PlayerLayoutResolver.resolve(1200), PlayerLayout.wide);
    });
  });

  testWidgets('Spotify import page exposes URL entry and import button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SpotifyImportPage()));
    expect(find.text('Import from Spotify'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Import playlist'), findsOneWidget);
  });
}
