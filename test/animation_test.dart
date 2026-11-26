import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/utils/page_transitions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EchoPage actually fades and slides while opening', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navKey,
          pages: const [
            MaterialPage<void>(child: SizedBox(key: Key('first'))),
          ],
          onPopPage: (route, result) => route.didPop(result),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final route = EchoPage<void>(
      child: const SizedBox(key: Key('content')),
    ).createRoute(navKey.currentContext!);
    navKey.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final content = find.byKey(const Key('content'));
    FadeTransition fade() => find
        .ancestor(of: content, matching: find.byType(FadeTransition))
        .evaluate()
        .first
        .widget as FadeTransition;
    SlideTransition slide() => find
        .ancestor(of: content, matching: find.byType(SlideTransition))
        .evaluate()
        .first
        .widget as SlideTransition;

    expect(fade().opacity.value, greaterThan(0.0));
    expect(fade().opacity.value, lessThan(1.0), reason: 'page must fade in');
    expect(slide().position.value.dy, greaterThan(0.0),
        reason: 'page must slide up into place');

    await tester.pumpAndSettle();
    expect(fade().opacity.value, 1.0);
    expect(find.byKey(const Key('content')), findsOneWidget);
  });
}
