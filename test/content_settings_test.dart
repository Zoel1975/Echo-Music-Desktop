import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_content_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I.registerSingleton<SettingsManager>(SettingsManager());
    }
  });

  test('content filter settings persist via SettingsManager', () {
    final s = GetIt.I<SettingsManager>();
    s.hideExplicit = true;
    s.hideVideoSongs = true;
    s.hideYouTubeShorts = true;
    s.sponsorBlock = true;
    s.contentLanguage = 'it';
    s.contentCountry = 'IT';

    expect(s.hideExplicit, isTrue);
    expect(s.hideVideoSongs, isTrue);
    expect(s.hideYouTubeShorts, isTrue);
    expect(s.sponsorBlock, isTrue);
    expect(s.contentLanguage, 'it');
    expect(s.contentCountry, 'IT');
  });
}
