import 'package:Echo/core/theme/tokens.dart';
import 'package:Echo/core/widgets/echo_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar renders four destinations and reports taps',
      (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EchoSidebar(
          selected: 0,
          extended: true,
          labels: const ['Home', 'Search', 'Library', 'Settings'],
          icons: const [
            Icons.home,
            Icons.search,
            Icons.library_music,
            Icons.settings,
          ],
          onDestinationSelected: tapped.add,
        ),
      ),
    ));

    expect(find.text('ECHO'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.library_music), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    expect(tapped, [1]);

    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text('ECHO'),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == EchoTokens.railWidth,
        ),
      ),
    );
    expect(container.decoration, isA<BoxDecoration>());
  });
}
