import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Live InnerTube check. Deliberately does NOT call
/// `TestWidgetsFlutterBinding.ensureInitialized()`, because that binding fakes
/// HTTP and turns every request into status 400. Here we want the real network
/// so the test proves the request headers work against YouTube Music.
///
/// Ignored by default (needs internet); run with:
///   flutter test test/yt_live_probe_test.dart --run-skipped
void main() {
  test('anonymous browse/playlists reach YouTube Music (real network)', () async {
    final dir = Directory('${Directory.systemTemp.path}/echo_live_probe');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!Hive.isBoxOpen('COOKIES')) await Hive.openBox('COOKIES');
    if (!Hive.isBoxOpen('ACCOUNT')) await Hive.openBox('ACCOUNT');

    final yt = YTMusic(
      config: YTConfig(visitorData: '', language: 'en', location: 'IT'),
    );

    final home = await yt
        .browse()
        .timeout(const Duration(seconds: 30));
    final sections = home['sections'] as List? ?? const [];
    // ignore: avoid_print
    print('LIVE browse sections=${sections.length}');
    expect(sections, isNotEmpty,
        reason: 'anonymous home feed must not be empty');

    final lib = await yt
        .getLibraryPlaylists()
        .timeout(const Duration(seconds: 30));
    // ignore: avoid_print
    print('LIVE library (anonymous) contents=${(lib['contents'] as List?)?.length}');
    expect(lib['contents'], isA<List>());

    // A signed-out library call must not crash on an empty response.
    expect((lib['contents'] as List?) ?? const [], isA<List>());
  }, skip: true, timeout: const Timeout(Duration(seconds: 90)));
}
