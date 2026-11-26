import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/utils/enhanced_image.dart';
import 'package:Echo/utils/song_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('missing thumbnails do not crash with NoSuchMethodError',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SongThumbnail(song: {'videoId': 'no-art'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  test('covers use the largest available thumbnail at the displayed size', () {
    final thumbs = [
      {'url': 'https://x/w60-h60', 'width': 60, 'height': 60},
      {'url': 'https://x/w120-h120', 'width': 120, 'height': 120},
      {'url': 'https://x/w544-h544', 'width': 544, 'height': 544},
    ];
    expect(bestThumbnailUrl(thumbs)!, contains('w800-h800'));
    expect(
      bestThumbnailUrl(thumbs, width: 300)!,
      contains('w300-h300'),
    );
    expect(
      getEnhancedImage('https://x/w120-h120', width: 260, dp: 2),
      contains('w520-h520'),
    );
    expect(bestThumbnailUrl(null), isNull);

    for (final file in [
      'lib/screens/detail/album_page.dart',
      'lib/screens/detail/artist_page.dart',
      'lib/screens/detail/playlist_page.dart',
      'lib/screens/library/widgets/my_playlist_header.dart',
      'lib/screens/library/widgets/library_tile.dart',
      'lib/core/widgets/section_item.dart',
      'lib/utils/bottom_modals.dart',
    ]) {
      expect(File(file).readAsStringSync(), contains('bestThumbnailUrl('));
    }
    final thumb = File('lib/utils/song_thumbnail.dart').readAsStringSync();
    expect(thumb, contains('maybeDevicePixelRatioOf(context)'));
    expect(thumb, isNot(contains('thumbnails.first')));

    final settings = File(
            'lib/screens/settings/player/player_settings_page.dart')
        .readAsStringSync();
    expect(settings, contains('S.of(context).VideoBehindArtwork'));
  });
}
