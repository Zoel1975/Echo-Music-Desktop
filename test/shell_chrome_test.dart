import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/core/widgets/floating_nav.dart';
import 'package:Echo/screens/shell/echo_shell_chrome.dart';

void main() {
  List<EchoNavDestination> destinations() => [
        EchoNavDestination(
            label: 'Home', icon: CupertinoIcons.music_house, onTap: () {}),
        EchoNavDestination(
            label: 'Search', icon: CupertinoIcons.search, onTap: () {}),
        EchoNavDestination(
            label: 'Saved', icon: Icons.library_music_outlined, onTap: () {}),
        EchoNavDestination(
            label: 'Settings', icon: CupertinoIcons.gear_alt, onTap: () {}),
      ];

  testWidgets('shell renders exactly ONE options/navigation bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EchoShellChrome(
            content: const SizedBox.expand(),
            bottom: const SizedBox(),
            selected: 0,
            destinations: destinations(),
          ),
        ),
      ),
    );

    // The one bar we want: the floating glass bar.
    expect(find.byType(EchoFloatingNavBar), findsOneWidget);

    // No second navigation surface may be present.
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('floating bar exposes all four destinations and taps report',
      (tester) async {
    final tapped = <int>[];
    final dests = [
      EchoNavDestination(label: 'Home', icon: Icons.home, onTap: () => tapped.add(0)),
      EchoNavDestination(label: 'Search', icon: Icons.search, onTap: () => tapped.add(1)),
      EchoNavDestination(label: 'Saved', icon: Icons.library_music, onTap: () => tapped.add(2)),
      EchoNavDestination(label: 'Settings', icon: Icons.settings, onTap: () => tapped.add(3)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EchoShellChrome(
            content: const SizedBox.expand(),
            bottom: const SizedBox(),
            selected: 1,
            destinations: dests,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.library_music), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    expect(tapped, [1]);
  });

  testWidgets('floating bar sits inside the viewport above the bottom edge',
      (tester) async {
    const size = Size(800, 600);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EchoShellChrome(
            // Taller-than-screen content must not push the bar off-screen.
            content: const SingleChildScrollView(
              child: SizedBox(height: 3000),
            ),
            bottom: const SizedBox(),
            selected: 0,
            destinations: destinations(),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(EchoFloatingNavBar));
    expect(rect.bottom, lessThan(size.height));
    expect(rect.top, greaterThan(0));
    // Anchored near the bottom (bottom: 76 with ~56px bar height).
    expect(size.height - rect.bottom, closeTo(76, 8));
  });

  testWidgets('section bar slides into the empty mini-player dock',
      (tester) async {
    const size = Size(800, 600);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hasPlayer = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EchoShellChrome(
            content: const SizedBox.expand(),
            bottom: const SizedBox(),
            hasPlayer: hasPlayer,
            selected: 0,
            destinations: destinations(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var rect = tester.getRect(find.byType(EchoFloatingNavBar));
    expect(size.height - rect.bottom, closeTo(76, 8),
        reason: 'with a track, the bar sits above the mini player');

    hasPlayer.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    rect = tester.getRect(find.byType(EchoFloatingNavBar));
    expect(size.height - rect.bottom, closeTo(12, 8),
        reason: 'no track: the bar takes the player space');

    hasPlayer.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    rect = tester.getRect(find.byType(EchoFloatingNavBar));
    expect(size.height - rect.bottom, closeTo(76, 8),
        reason: 'the bar moves back up when a track starts');
  });
}
