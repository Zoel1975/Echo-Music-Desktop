import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:Echo/screens/settings/appearance/appearance_details_page.dart';
import 'package:Echo/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_appearance_details_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I.registerSingleton<SettingsManager>(SettingsManager());
    }
  });

  testWidgets('Appearance details mirrors Android options (real + placeholders)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<SettingsManager>.value(
        value: GetIt.I<SettingsManager>(),
        child: const AppearanceDetailsPage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    // Real persisted options.
    for (final label in [
      'Theme variant',
      'Navigation bar style',
      'Blur radius',
      'Surface opacity',
      'Vibrancy',
      'Glass player',
      'Apple Music inspired',
      'Thumbnail corner radius',
      'Crop album art',
      'Player button colors',
      'Player slider style',
      'Wavy play/pause button',
      'Rotating thumbnail',
      'Show codec on player',
      'Mini-player swipe sensitivity',
      'Word-by-word animation',
      'Lyrics line spacing',
      'Change lyrics on click',
      'Grid cell size',
      'Display density',
      'Haptic intensity',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }

    // Android-only placeholders.
    for (final label in ['App Icon', 'App Font', 'Hide status bar on fullscreen']) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }
  });

  test('extra settings persist with runtime-relevant values', () {
    final s = GetIt.I<SettingsManager>();
    s.setExtra<String>('gridCellSize', 'Large');
    s.setExtra<double>('lyricsLineSpacing', 14);
    s.setExtra<bool>('showCodec', true);
    expect(s.extra<String>('gridCellSize', 'Medium'), 'Large');
    expect(s.extra<double>('lyricsLineSpacing', 8), 14);
    expect(s.extra<bool>('showCodec', false), isTrue);
  });
}
