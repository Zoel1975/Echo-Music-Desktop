import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/screens/coming_soon/coming_soon_catalog.dart';
import 'package:Echo/screens/coming_soon/coming_soon_page.dart';

void main() {
  test('all formerly-placeholdered features are now real screens', () {
    // The placeholder catalog is empty: every parity feature is reachable as
    // a real screen (settings integrations, podcasts, music flow, ambient,
    // export, song DNA).
    expect(ComingSoonCatalog.features, isEmpty);
    for (final route in [
      'podcasts',
      'canvas_ambient',
      'music_flow_full',
      'export_queue',
      'song_dna',
    ]) {
      expect(
        ComingSoonCatalog.byRoute('/$route'),
        isNull,
        reason: '$route should no longer be a placeholder',
      );
    }
  });

  testWidgets('placeholder page still shows an honest future-update message',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ComingSoonPage(
        title: 'Example future feature',
        feature: 'This is planned for a future update.',
      ),
    ));
    expect(find.text('Example future feature'), findsWidgets);
    expect(find.text('Planned for a future update'), findsOneWidget);
    expect(find.byIcon(Icons.construction_rounded), findsOneWidget);
  });
}
