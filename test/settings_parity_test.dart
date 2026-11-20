import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/generated/l10n.dart';
import 'package:Echo/screens/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = _StubHttp();
    final dir = Directory('${Directory.systemTemp.path}/echo_settings_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    for (final name in ['SETTINGS', 'COOKIES', 'ACCOUNT']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  testWidgets('Settings menu mirrors all Android entries (real + placeholders)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: const SettingsPage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Real, reachable features.
    for (final label in [
      'Account',
      'AI Hub',
      'Listening Summary',
      'Echo Wrapped',
      'Appearence',
      'Player and audio',
      'Music Flow',
      'Content',
      'Privacy',
      'Storage',
      'Backup and restore',
      'Youtube Music',
      'System update',
      'About',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }

    // Placeholder features from the mobile app.
    for (final label in [
      'Listen Together',
      'Discord Rich Presence',
      'Last.fm / ListenBrainz',
      'Jellyfin / Navidrome',
      'Supported Links',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }
  });
}

class _StubHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}




