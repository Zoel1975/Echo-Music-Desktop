import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/ytmusic/mixins/browsing.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

class _FakeYt extends YTMusic {
  _FakeYt() : super(config: YTConfig(visitorData: '', language: 'en', location: 'IT'));

  int calls = 0;

  @override
  Future<Map> sendRequest(String endpoint, Map<String, dynamic> body,
      {Map<String, String>? headers, String additionalParams = ''}) async {
    calls++;
    if (additionalParams.contains('TOKEN2')) {
      return {
        'continuationContents': {
          'sectionListContinuation': {
            'contents': [
              {
                'musicPlaylistShelfRenderer': {
                  'contents': [
                    for (final id in ['last1', 'last2'])
                      {
                        'playlistPanelVideoRenderer': {
                          'videoId': id,
                          'title': {'runs': [{'text': id}]},
                          'thumbnail': {
                            'thumbnails': [
                              {'url': 'https://img/$id'}
                            ]
                          },
                          'setVideoId': 'set-$id',
                        }
                      }
                  ],
                }
              }
            ],
          }
        }
      };
    }
    final firstPage = [
      for (var i = 0; i < 100; i++)
        {
          'playlistPanelVideoRenderer': {
            'videoId': 'v$i',
            'title': {'runs': [{'text': 'Song $i'}]},
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://img/$i'}
              ]
            },
            'setVideoId': 'set-$i',
          }
        }
    ];
    return {
      'contents': {
        'singleColumnBrowseResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    // Real YouTube places the token here, not on the shelf.
                    'continuations': [
                      {'nextContinuationData': {'continuation': 'TOKEN2'}}
                    ],
                    'contents': [
                      {
                        'musicPlaylistShelfRenderer': {
                          'contents': firstPage,
                        }
                      }
                    ],
                  }
                }
              }
            }
          ]
        }
      }
    };
  }
}

void main() {
  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_pagination_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    for (final box in ['SETTINGS', 'COOKIES', 'ACCOUNT']) {
      if (!Hive.isBoxOpen(box)) await Hive.openBox(box);
    }
  });

  test('getMoreItems understands sectionListContinuation (real playlists)',
      () async {
    final yt = _FakeYt();
    // The fake returns sectionListContinuation from getMoreItems; the first
    // call in the other test already exercised the shelf path, so cover the
    // section-list shape explicitly with a direct call.
    final more = await yt.getMoreItems(continuation: '&ctoken=TOKEN2&continuation=TOKEN2');
    expect(more['items'], isA<List>());
  });

  test('getPlaylistSongs follows continuations past 100 tracks', () async {
    final yt = _FakeYt();
    final songs = await yt.getPlaylistSongs('VLPL123');
    expect(songs, hasLength(102),
        reason: 'first page 100 + continuation 2; desktop must not stop at 100');
    expect(songs.first['videoId'], 'v0');
    expect(songs.last['videoId'], 'last2');
    expect(songs.last['setVideoId'], 'set-last2');
    expect(yt.calls, 2);
  });
}
