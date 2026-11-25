import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/utils/bottom_modals.dart';

void main() {
  testWidgets('player popup exposes stems', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Modals.showPlayerOptionsModal(
              context,
              {'videoId': 'x', 'title': 'Probe'},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Stems'), findsOneWidget);
  });
}
