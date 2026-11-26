import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote control HTML escapes metadata and sets security headers',
      () {
    final src = File('lib/services/remote_control_service.dart')
        .readAsStringSync();
    expect(src, contains('escapeRemoteHtml'));
    expect(src, contains('const HtmlEscape().convert'));
    expect(src, contains(r'<h1>${escapeRemoteHtml(title)}</h1>'));
    for (final header in [
      'X-Content-Type-Options',
      'X-Frame-Options',
      'Referrer-Policy',
      'Cache-Control',
    ]) {
      expect(src, contains(header), reason: 'missing header $header');
    }
  });

  test('Spotify client secret is configured, not bundled', () {
    final service = File('lib/services/spotify.dart').readAsStringSync();
    expect(service, isNot(contains("clientSecret = '")));
    expect(service, contains('SPOTIFY_CLIENT_SECRET'));
    expect(service, contains('client secret is not configured'));

    final page = File(
            'lib/screens/settings/services/spotify/spotify_import_page.dart')
        .readAsStringSync();
    expect(page, contains('Spotify client secret'));
    expect(page, contains('obscureText: true'));
  });

  test('the LAN control setting warns that it is unauthenticated', () {
    final page =
        File('lib/screens/settings/player/player_settings_page.dart')
            .readAsStringSync();
    expect(page, contains('Unauthenticated: enable only on a trusted network'));
  });

  test('the local CDP debug port is not open to every origin', () {
    final src = File('lib/services/google_login_service.dart').readAsStringSync();
    expect(src, isNot(contains('--remote-allow-origins=*')));
    expect(src, contains(r'--remote-allow-origins=http://127.0.0.1:$port'));
  });

  test('gitleaks allowlists only public client identifiers', () {
    final config = File('.gitleaks.toml').readAsStringSync();
    expect(config, contains('useDefault = true'));
    expect(config, contains('AIza[0-9A-Za-z_\\-]{35}'));
    expect(config, isNot(contains('fb01ad204aff4c12bbcb3ca7ac617990')));
  });
}
