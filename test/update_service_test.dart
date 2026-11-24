import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

import 'package:Echo/services/update_service/update_service.dart';

void main() {
  test('auto-update checks this project\'s GitHub releases', () {
    final src = File('lib/services/update_service/update_service.dart')
        .readAsStringSync();
    expect(src, contains("owner = 'ItsZale0'"));
    expect(src, contains("repo = 'Echo-Music-Desktop'"));
    expect(src, contains(r'api.github.com/repos/$owner/$repo/releases/latest'));
    expect(src, contains("installerAsset = 'EchoMusicSetup.exe'"));
    expect(src, isNot(contains('iad1tya/Echo-Music')));
    expect(src, isNot(contains('desktop_update.json')));
    // The old JSON endpoint is gone (404); a missing file must not silently
    // mean "up to date". Equal/older tags must not trigger a false prompt.
    expect(src, contains('remoteVersion <= currentVersion'));
    expect(src, contains('Version.parse(cleanTag)'));
    expect(src, contains('Duration(seconds: 15)'));
  });

  test('the update settings screen is in English', () {    final page = File('lib/screens/settings/update_settings_page.dart')
        .readAsStringSync();
    expect(page, contains('Check for updates'));
    for (final legacy in [
      'Controlla aggiornamenti',
      'Controllo in corso',
      'Stai usando',
      'Versione installata',
    ]) {
      expect(page, isNot(contains(legacy)), reason: 'italian leftover: $legacy');
    }
  });

  test('a newer release points at this repo\'s Windows installer', () {
    final info = UpdateService.fromReleaseJson(
      {
        'tag_name': 'v1.1.0',
        'name': 'Echo Music Desktop 1.1.0',
        'body': 'Release notes',
        'published_at': '2026-11-24',
        'assets': [
          {
            'name': 'EchoMusicPortable.zip',
            'browser_download_url': 'https://example.invalid/portable.zip',
          },
          {
            'name': 'EchoMusicSetup.exe',
            'browser_download_url':
                'https://github.com/ItsZale0/Echo-Music-Desktop/releases/download/v1.1.0/EchoMusicSetup.exe',
          },
        ],
      },
      Version.parse('1.0.0'),
    );
    expect(info, isNotNull);
    expect(info!.version.toString(), '1.1.0');
    expect(info.downloadUrl, contains('ItsZale0/Echo-Music-Desktop'));
    expect(info.downloadUrl, endsWith('EchoMusicSetup.exe'));
  });

  test('equal or older tags are not updates', () {
    for (final tag in ['v1.0.0', 'v0.9.0', 'garbage']) {
      expect(
        UpdateService.fromReleaseJson({'tag_name': tag}, Version.parse('1.0.0')),
        isNull,
        reason: '$tag must not trigger an update prompt',
      );
    }
  });

  test('a release without a Windows installer falls back to the releases page',
      () {
    final info = UpdateService.fromReleaseJson(
      {'tag_name': 'v1.2.0', 'assets': []},
      Version.parse('1.0.0'),
    );
    expect(info, isNotNull);
    expect(info!.downloadUrl, UpdateService.releasesPage);
  });
}
