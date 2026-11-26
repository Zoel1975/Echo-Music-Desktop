import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/auto_playlists.dart';

void main() {
  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_auto_pl_test');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    Hive.init(dir.path);
    await Hive.openBox('SONG_HISTORY');
    await Hive.openBox('DOWNLOADS');
  });

  test('top / bottom come from SONG_HISTORY play counts', () async {
    final history = Hive.box('SONG_HISTORY');
    await history.clear();
    await history.put('a', {
      'videoId': 'a',
      'title': 'Often played',
      'artist': 'A',
      'plays': 12,
    });
    await history.put('b', {
      'videoId': 'b',
      'title': 'Rarely played',
      'artist': 'B',
      'plays': 1,
    });
    await history.put('c', {
      'videoId': 'c',
      'title': 'Never played',
      'artist': 'C',
      'plays': 0,
    });

    final top = AutoPlaylists.top();
    expect(top.first['videoId'], 'a');
    expect(top.map((s) => s['videoId']), containsAll(['a', 'b', 'c']));

    final bottom = AutoPlaylists.bottom();
    expect(bottom.first['videoId'], 'b');
    expect(bottom.map((s) => s['videoId']), isNot(contains('c')));
  });

  test('cached comes from downloaded files on disk', () async {
    final downloads = Hive.box('DOWNLOADS');
    await downloads.clear();
    final file = File('${Directory.systemTemp.path}/echo_cached_probe.mp3');
    file.writeAsBytesSync([1, 2, 3]);
    await downloads.put('d', {
      'videoId': 'd',
      'title': 'Offline song',
      'status': 'DOWNLOADED',
      'path': file.path,
    });
    await downloads.put('e', {
      'videoId': 'e',
      'title': 'Not downloaded',
      'status': 'QUEUED',
    });

    final cached = AutoPlaylists.cached();
    expect(cached.length, 1);
    expect(cached.first['videoId'], 'd');
    file.deleteSync();
  });

  test('the three toggles are wired to the library', () {
    final library =
        File('lib/screens/library/library_page.dart').readAsStringSync();
    expect(library, contains('AutoPlaylists.top()'));
    expect(library, contains('AutoPlaylists.bottom()'));
    expect(library, contains('AutoPlaylists.cached()'));
    expect(library, contains("'showTopPlaylist'"));
    expect(library, contains("'showBottomPlaylist'"));
    expect(library, contains("'showCachedPlaylist'"));
  });
}
