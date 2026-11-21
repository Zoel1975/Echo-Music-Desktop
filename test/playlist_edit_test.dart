import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/ytmusic/mixins/playlist_edit.dart';
import 'package:Echo/utils/playable.dart';
import 'package:Echo/utils/safe_cast.dart';

void main() {
  test('safeMapList fixes the List<dynamic> cast crash from jsonDecode', () {
    final decoded =
        jsonDecode('[{"url":"https://img/1.jpg"},{"url":"https://img/2.jpg"}]');
    expect(decoded, isA<List<dynamic>>());
    final result = safeMapList(decoded);
    expect(result, hasLength(2));
    expect(result.first['url'], 'https://img/1.jpg');
    expect(safeMapList(null), isEmpty);
    expect(safeMapList('not a list'), isEmpty);
  });

  test('add / remove / rename follow Android InnerTube actions', () {
    final context = {'client': {'clientName': 'WEB_REMIX'}};
    final add = PlaylistEditMixin.editBody(
      'VLPL123',
      {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': 'video1'},
      context,
    );
    expect(add['playlistId'], 'PL123');
    expect(add['context'], context);
    expect(add['actions'], [
      {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': 'video1'}
    ]);

    final remove = PlaylistEditMixin.editBody(
      'PL123',
      {
        'action': 'ACTION_REMOVE_VIDEO',
        'setVideoId': 'set-9',
        'removedVideoId': 'video1'
      },
      context,
    );
    expect(remove['actions'], [
      {
        'action': 'ACTION_REMOVE_VIDEO',
        'setVideoId': 'set-9',
        'removedVideoId': 'video1'
      }
    ]);

    final rename = PlaylistEditMixin.editBody(
      'PL123',
      {'action': 'ACTION_SET_PLAYLIST_NAME', 'playlistName': 'Nuova'},
      context,
    );
    expect(rename['actions'], [
      {'action': 'ACTION_SET_PLAYLIST_NAME', 'playlistName': 'Nuova'}
    ]);

    final src = File('lib/ytmusic/mixins/playlist_edit.dart').readAsStringSync();
    expect(src, contains("sendRequest('browse/edit_playlist'"));
    expect(src, contains("sendRequest('playlist/create'"));
    final yt = File('lib/ytmusic/ytmusic.dart').readAsStringSync();
    expect(yt, contains('PlaylistEditMixin'));
  });

  test('setVideoId survives conversion into a playable song', () {
    final song = toPlaySong({
      'videoId': 'abc',
      'title': 'Song',
      'setVideoId': 'set-abc',
      'thumbnails': [
        {'url': 'u'}
      ],
    });
    expect(song['videoId'], 'abc');
    expect(song['setVideoId'], 'set-abc');
  });
}
