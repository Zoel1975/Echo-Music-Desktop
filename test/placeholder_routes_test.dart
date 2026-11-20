import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/screens/coming_soon/coming_soon_catalog.dart';
import 'package:Echo/screens/coming_soon/coming_soon_page.dart';

void main() {
  test('every remaining parity feature has a stable reachable route', () {
    final routes = ComingSoonCatalog.features.map((f) => '/${f.route}').toList();
    expect(routes, containsAll([
      '/podcasts',
      '/canvas_ambient',
      '/music_flow_full',
      '/song_dna',
      '/export_queue',
    ]));
    for (final f in ComingSoonCatalog.features) {
      expect(ComingSoonCatalog.byRoute('/${f.route}')?.title, f.title);
      expect(f.message, isNotEmpty);
    }
    expect(ComingSoonCatalog.byRoute('/unknown'), isNull);
  });

  testWidgets('placeholder page shows an honest future-update message',
      (tester) async {
    final feature = ComingSoonCatalog.features.first;
    await tester.pumpWidget(MaterialApp(
      home: ComingSoonPage(
        title: feature.title,
        feature: feature.message,
      ),
    ));
    expect(find.text(feature.title), findsWidgets);
    expect(find.text('Planned for a future update'), findsOneWidget);
    expect(find.byIcon(Icons.construction_rounded), findsOneWidget);
  });
}
