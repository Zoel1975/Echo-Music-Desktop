import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
