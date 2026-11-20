import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/library_aggregation.dart';

void main() {
  final songs = [
    {
      'videoId': 'a',
      'title': 'Song A',
      'artists': [
        {'name': 'Artist One'}
      ],
      'album': {'name': 'Album X'},
    },
    {
      'videoId': 'b',
      'title': 'Song B',
      'artists': [
        {'name': 'Artist One'}
      ],
      'album': {'name': 'Album X'},
    },
    {
      'videoId': 'a',
      'title': 'Song A duplicate',
      'artists': [
        {'name': 'Artist One'}
      ],
      'album': {'name': 'Album X'},
    },
    {
      'videoId': 'c',
      'title': 'Song C',
      'artists': [
        {'name': 'Artist Two'}
      ],
      'album': {'name': 'Album Y'},
    },
  ];

  test('songList de-duplicates by videoId', () {
    final list = LibraryAggregation.songList(songs);
    expect(list.length, 3);
    expect(list.map((s) => s['videoId']), {'a', 'b', 'c'});
  });

  test('albums groups songs by album name', () {
    final albums = LibraryAggregation.albums(songs);
    expect(albums.length, 2);
    final x = albums.firstWhere((a) => a['name'] == 'Album X');
    expect((x['songs'] as List).length, 3);
    final y = albums.firstWhere((a) => a['name'] == 'Album Y');
    expect((y['songs'] as List).length, 1);
  });

  test('artists groups songs by first artist', () {
    final artists = LibraryAggregation.artists(songs);
    expect(artists.length, 2);
    final one = artists.firstWhere((a) => a['name'] == 'Artist One');
    expect((one['songs'] as List).length, 3);
    final two = artists.firstWhere((a) => a['name'] == 'Artist Two');
    expect((two['songs'] as List).length, 1);
  });

  test('filter matches title and artist-group name', () {
    final list = LibraryAggregation.songList(songs);
    expect(LibraryAggregation.filter(list, 'SONG a').length, 1);
    expect(LibraryAggregation.filter(list, 'zzz'), isEmpty);
    final artists = LibraryAggregation.artists(songs);
    expect(LibraryAggregation.filter(artists, 'artist two').length, 1);
  });
}
