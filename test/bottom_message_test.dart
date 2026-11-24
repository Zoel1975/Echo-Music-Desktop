import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/bottom_message.dart';

/// Widget-level regression for the invisible-toast bug: on Windows the theme's
/// scaffold background is `Colors.transparent`, and the old toast reused it as
/// the text colour, so every message looked like an empty coloured bar.
void main() {
  ThemeData windowsTheme() => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
      );

  Future<void> showToast(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: windowsTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => BottomMessage.showText(context, text),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('toast text is opaque on a transparent scaffold background',
      (tester) async {
    await showToast(tester, 'Export started...');

    expect(find.text('Export started...'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Export started...'));
    final color = text.style?.color;
    expect(color, isNotNull);
    expect(color!.alpha, greaterThan(0),
        reason: 'transparent text makes the message invisible');
    expect(color, isNot(Colors.transparent));
  });

  testWidgets('toast text contrasts with the toast background',
      (tester) async {
    await showToast(tester, 'Saved to your Music folder');

    final text = tester.widget<Text>(find.text('Saved to your Music folder'));
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final background = snackBar.backgroundColor!;
    final foreground = text.style!.color!;

    // WCAG-ish check: a luminance difference of 0.3 is clearly readable.
    final delta =
        (foreground.computeLuminance() - background.computeLuminance()).abs();
    expect(delta, greaterThan(0.3),
        reason: 'foreground $foreground on $background is not readable');
  });
}
