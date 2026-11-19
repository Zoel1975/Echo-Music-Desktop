import 'package:Echo/utils/playable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toPlaySong', () {
    test('maps YTMusic item shape to MediaPlayer shape', () {
      final song = toPlaySong({
        'title': 'Song',
        'videoId': 'abc123',
        'artists': [
          {'name': 'Artist 1', 'endpoint': {'browseId': 'X'}},
          {'name': 'Artist 2'},
        ],
        'album': {'name': 'Album'},
        'thumbnails': [
          {'url': 'u1', 'width': 60, 'height': 60},
          {'url': 'u2', 'width': 225, 'height': 225},
        ],
      });

      expect(song['videoId'], 'abc123');
      expect(song['title'], 'Song');
      expect((song['artists'] as List).map((e) => e['name']).join(','),
          'Artist 1,Artist 2');
      expect((song['artists'] as List).first['name'], isNotEmpty);
      expect(song['album'], isA<Map>());
      expect(song['thumbnails'], isA<List>());
    });

    test('falls back to subtitle when artists are missing', () {
      final song = toPlaySong({
        'title': 'Song',
        'videoId': 'v',
        'subtitle': 'Someone • Dim the Lights',
      });
      expect((song['artists'] as List).length, 1);
      expect(song['artists'][0]['name'], 'Someone');
    });

    test('no artists when neither artists nor subtitle is present', () {
      final song = toPlaySong({'title': 'Song', 'videoId': 'v'});
      expect(song['artists'], isEmpty);
    });

    test('handles playlistPanelVideoRenderer items (Online Playlist)', () {
      final song = toPlaySong({
        'title': 'First',
        'videoId': 'xyz',
        'thumbnails': [
          {'url': 'u', 'width': 225, 'height': 225},
        ],
        'subtitle': 'First Artist',
        'type': 'SONG',
      });
      expect(song['title'], 'First');
      expect(song['videoId'], 'xyz');
      expect(song['subtitle'], 'First Artist');
    });
  });

  group('toPlaySongs', () {
    test('converts a list of items', () {
      final songs = toPlaySongs([
        {'title': 'A', 'videoId': '1', 'artists': []},
        {'title': 'B', 'videoId': '2', 'artists': []},
      ]);
      expect(songs.map((s) => s['videoId']), ['1', '2']);
    });
  });
}
