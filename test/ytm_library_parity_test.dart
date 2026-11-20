import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test: the signed-in YouTube Music library is reachable and
/// backed by the real LibraryMixin endpoints (this is what visibly changes
/// after login, unlike the local-only Library page).
void main() {
  test('YTM library route is registered', () {
    final router = File('lib/utils/router.dart').readAsStringSync();
    expect(router, contains("path: '/ytm_library'"));
    expect(router, contains('YtmLibraryPage'));
  });

  test('YTM library uses real LibraryMixin endpoints + account refresh', () {
    final page = File('lib/screens/library/ytm_library_page.dart')
        .readAsStringSync();
    for (final call in [
      'getLibraryPlaylists()',
      'getLibrarySongs()',
      'getLibraryAlbums()',
      'getLibraryArtists()',
      'accountEpoch',
      'CookieStore.instance.cookieHeader',
    ]) {
      expect(page, contains(call), reason: 'missing: $call');
    }
  });

  test('YTM library is the DEFAULT route of the Saved tab; local is secondary', () {
    final router = File('lib/utils/router.dart').readAsStringSync();
    final savedBlock = router.substring(router.indexOf("path: '/saved'"));
    final segment = savedBlock.substring(0, savedBlock.indexOf('routes: ['));
    expect(segment, contains('const YtmLibraryPage()'),
        reason: 'Saved tab should open the signed-in YT library by default');
    expect(savedBlock, contains("path: 'local'"));
  });

  test('Library page exposes the YTM library entry point', () {
    final lib = File('lib/screens/library/library_page.dart').readAsStringSync();
    expect(lib, contains("context.push('/ytm_library')"));
    expect(lib, contains('YouTube Music library'));
  });
}
