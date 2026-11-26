import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:Echo/screens/settings/integrations/integration_catalog.dart';
import 'package:Echo/screens/settings/integrations/integration_page.dart';
import 'package:Echo/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_integration_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I.registerSingleton<SettingsManager>(SettingsManager());
    }
  });

  test('integration catalog covers all Android settings screens', () {
    final routes = IntegrationCatalog.screens.map((s) => '/${s.route}').toList();
    expect(routes, containsAll([
      '/discord',
      '/lastfm',
      '/jellyfin',
      '/listen_together',
      '/extensions',
      '/song_dna',
    ]));
    for (final screen in IntegrationCatalog.screens) {
      expect(IntegrationCatalog.byRoute('/${screen.route}')?.title, screen.title);
      expect(screen.fields, isNotEmpty);
    }
  });

  testWidgets('integration page renders persisted credential fields',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final screen = IntegrationCatalog.byRoute('/discord')!;
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<SettingsManager>.value(
        value: GetIt.I<SettingsManager>(),
        child: IntegrationPage(screen: screen),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    for (final label in [
      'Enable Discord RPC',
      'Application ID (client_id)',
      'Access token',
      'Activity type',
      'Activity name',
      'Show when paused',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing: $label');
    }
  });

  test('Last.fm screen exposes secret and session key fields', () {
    final lastfm = IntegrationCatalog.byRoute('/lastfm')!;
    final keys = lastfm.fields.map((f) => f.key).toList();
    expect(keys, contains('lastfmApiKey'));
    expect(keys, contains('lastfmApiSecret'));
    expect(keys, contains('lastfmSessionKey'));
  });

  test('integration credentials persist via SettingsManager.extra', () {
    final s = GetIt.I<SettingsManager>();
    s.setExtra<String>('discordToken', 'secret-token');
    s.setExtra<bool>('discordEnabled', true);
    s.setExtra<String>('geniusToken', 'genius-secret');
    expect(s.extra<String>('discordToken', ''), 'secret-token');
    expect(s.extra<bool>('discordEnabled', false), isTrue);
    expect(s.extra<String>('geniusToken', ''), 'genius-secret');
  });
}
