import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/generated/l10n.dart';
import 'package:Echo/screens/settings/appearance/appearance_page.dart';
import 'package:Echo/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_appearance_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I.registerSingleton<SettingsManager>(SettingsManager());
    }
  });

  testWidgets('Appearance page mirrors Android AppearanceSettings groups',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: const AppearancePage(),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    // Real persisted settings groups.
    for (final label in [
      'Theme',
      'Mini-player',
      'Mini-player background style',
      'Player',
      'Player background style',
      'Hide Player Thumbnail',
      'Lyrics',
      'Lyrics text position',
      'Lyrics text size',
      'Auto scroll lyrics',
      'Misc',
      'Default open tab',
      'Auto playlists',
      'Show "Liked" playlist',
      'Show "Downloaded" playlist',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }

    // Android-only placeholders.
    for (final label in [
      'App Icon',
      'App Font',
      'Liquid Glass (Beta)',
      'Haptics',
      'Enable high refresh rate',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }
  });

  test('appearance settings persist via SettingsManager', () {
    final s = GetIt.I<SettingsManager>();
    s.miniPlayerStyle = 'Solid';
    s.lyricsTextSize = 24;
    s.lyricsAutoScroll = false;
    s.defaultTab = 2;
    s.showLikedPlaylist = false;
    expect(s.miniPlayerStyle, 'Solid');
    expect(s.lyricsTextSize, 24);
    expect(s.lyricsAutoScroll, isFalse);
    expect(s.defaultTab, 2);
    expect(s.showLikedPlaylist, isFalse);
  });
}

