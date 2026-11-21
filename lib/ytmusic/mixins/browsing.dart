import 'dart:core';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:Echo/ytmusic/client.dart';
import 'package:Echo/services/cookie_store.dart';

import '../helpers.dart';
import 'utils.dart';

mixin BrowsingMixin on YTClient {
  Future<Map<String, dynamic>> browse(
      {Map<String, dynamic>? body,
      int limit = 2,
      String additionalParams = ''}) async {
    if (additionalParams != '') {
      return browseContinuation(
          body: body, limit: limit, additionalParams: additionalParams);
    }
    String endpoint = 'browse';
    body ??= {"browseId": "FEmusic_home"};

    var response =
        await sendRequest(endpoint, body, additionalParams: additionalParams);

    Map<String, dynamic> result = {};
    Map<String, dynamic>? contents = response['contents'];

    Map<String, dynamic>? header = response['header'] ??
        nav(response, [
          'contents',
          'twoColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0
        ]);

    if (header != null) {
      result['header'] = handlePageHeader(
          header['musicDetailHeaderRenderer'] ??
              header['musicImmersiveHeaderRenderer'] ??
              header['musicResponsiveHeaderRenderer'] ??
              header['musicVisualHeaderRenderer'] ??
              header['musicHeaderRenderer'] ??
              header['musicEditablePlaylistDetailHeaderRenderer']?['header']
                  ?['musicResponsiveHeaderRenderer'] ??
              header['musicEditablePlaylistDetailHeaderRenderer']?['header'],
          editHeader: header['musicEditablePlaylistDetailHeaderRenderer']
              ?['editHeader']?['musicPlaylistEditHeaderRenderer']);
    }

    if (contents != null) {
      Map? tabRenderer = nav(contents,
          ['singleColumnBrowseResultsRenderer', 'tabs', 0, 'tabRenderer']);
      Map? sectionListRenderer =
          nav(tabRenderer, ['content', 'sectionListRenderer']) ??
              nav(contents, [
                'twoColumnBrowseResultsRenderer',
                'secondaryContents',
                'sectionListRenderer'
              ]);
      List? chips =
          nav(sectionListRenderer, ['header', 'chipCloudRenderer', 'chips']);
      if (chips != null) {
        result['chips'] = [];
        result['chips'].addAll(handleChips(chips));
      }
      String? cont = nav(sectionListRenderer,
              ['continuations', 0, 'nextContinuationData', 'continuation']) ??
          nav(sectionListRenderer, [
            'contents',
            0,
            'musicShelfRenderer',
            'continuations',
            0,
            'nextContinuationData',
            'continuation'
          ]);

      String? continuationparams;
      if (cont != null) {
        continuationparams = getContinuationString(cont);
        result['continuation'] = continuationparams;
      } else {
        result['continuation'] = null;
      }

      List finalContents = nav(sectionListRenderer, ['contents']);

      result['sections'] = handleOuterContents(finalContents,
          thumbnails: result['header']?['thumbnails']);
      (result['sections'] as List).removeWhere((el) => el['contents'].isEmpty);
      if (limit > 1 && continuationparams != null) {
        limit = limit - 1;

        var data = await browseContinuation(
            body: body, limit: limit, additionalParams: continuationparams);
        if (data['sections'] != null) {
          if (data['addToLast'] == true) {
            result['sections']
                .last['contents']
                .addAll(data['sections'].first['contents']);
          } else {
            result['sections']
                .addAll(data['sections'].cast<Map<String, dynamic>>());
          }
        }
        result['continuation'] = data['continuation'];
      }
    } else {
      result['sections'] = List<Map<String, dynamic>>.empty();
    }
    return result;
  }

  Future<Map<String, dynamic>> browseContinuation(
      {Map<String, dynamic>? body,
      int limit = 1,
      String additionalParams = ''}) async {
    String endpoint = 'browse';
    body ??= {"browseId": "FEmusic_home"};

    var response =
        await sendRequest(endpoint, body, additionalParams: additionalParams);
    Map<String, dynamic> result = {'sections': []};

    List? contents = nav(response,
            ['continuationContents', 'sectionListContinuation', 'contents']) ??
        nav(response,
            ['continuationContents', 'musicShelfContinuation', 'contents']);

    if (contents == null) return {};
    if (nav(response,
            ['continuationContents', 'musicShelfContinuation', 'contents']) !=
        null) {
      result['sections'].add({'contents': handleContents(contents)});
      result['addToLast'] = true;
    } else {
      result['sections'] = handleOuterContents(contents);
    }

    String? continuations = nav(response, [
          'continuationContents',
          'sectionListContinuation',
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]) ??
        nav(response, [
          'continuationContents',
          'musicShelfContinuation',
          'continuations',
          0,
          'nextContinuationData',
          'continuation'
        ]);
    if (continuations != null) {
      String? continuationparams = getContinuationString(continuations);
      result['continuation'] = continuationparams;
    } else {
      result['continuation'] = null;
    }

    if (limit > 1 && result['continuation'] != null) {
      limit = limit - 1;
      var data = await browse(
          body: body, limit: limit, additionalParams: result['continuation']);
      if (data['sections'] != null) {
        result['sections'].addAll(data['sections']);
      }
      result['continuation'] = data['continuation'];
    }

    return result;
  }

  Future<Map<String, dynamic>> getMoreItems({continuation = ''}) async {
    final response = await sendRequest('browse', {'browseId': 'FEmusic_home'},
        additionalParams: continuation);
    final containers = response['continuationContents'];
    if (containers is! Map) return {'items': const [], 'continuation': null};

    // Playlist continuations come back as `sectionListContinuation`, while
    // search/library shelves use `musicPlaylistShelfContinuation` or
    // `musicShelfContinuation`. Support all of them.
    Map? shelf = containers['musicPlaylistShelfContinuation'] as Map? ??
        containers['musicShelfContinuation'] as Map?;
    Map? sectionList = containers['sectionListContinuation'] as Map?;
    if (shelf == null && sectionList != null) {
      final inner = nav(sectionList, ['contents', 0]) as Map?;
      shelf = inner?['musicPlaylistShelfRenderer'] as Map? ??
          inner?['musicShelfRenderer'] as Map? ??
          sectionList;
    }
    if (shelf == null) return {'items': const [], 'continuation': null};

    List contents = nav(shelf, ['contents']) as List? ?? const [];
    final continuationString = _playlistContinuation(shelf) ??
        _playlistContinuation(sectionList) ??
        nav(containers, [
          'sectionListContinuation',
          'continuations',
          0,
          'nextContinuationData',
          'continuation',
        ]) as String?;
    return {
      'items': handleContents(contents),
      'continuation': continuationString == null
          ? null
          : getContinuationString(continuationString),
    };
  }

  int getDatestamp() {
    final DateTime now = DateTime.now();
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final Duration difference = now.difference(epoch);
    final int days = difference.inDays;
    return days;
  }

  Future addYoutubeHistory(String videoId) async {
    signatureTimestamp = signatureTimestamp ?? getDatestamp() - 1;
    Map<String, dynamic> body = {};
    body['playbackContext'] = {
      'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
    };
    body['video_id'] = videoId;

    final Map response = await sendRequest('player', body);
    if (response.isEmpty) return;
    String url =
        response['playbackTracking']['videostatsPlaybackUrl']['baseUrl'];
    const String cpna =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    Random rand = Random();

    String generateCpn() {
      return List.generate(16, (index) => cpna[rand.nextInt(64)]).join();
    }

    String cpn = generateCpn();
    Map<String, dynamic> params = {"ver": 2, "c": "WEB_REMIX", "cpn": cpn};
    params.forEach((k, v) {
      url += '&$k=$v';
    });
    await sendGetRequest(url, headers);
  }

  Future<Map<String, dynamic>?> getSongDetails(String videoId) async {
    Map<String, dynamic> body = {"videoId": videoId};
    final Map response = await sendRequest('player', body);
    Map? videoDetails = response['videoDetails'];
    if (videoDetails != null) {
      return {
        'videoId': videoDetails['videoId'],
        'channelId': videoDetails['channelId'],
        'title': videoDetails['title'],
        'subtitle': videoDetails['author'],
        'length': videoDetails['lengthSeconds'],
        'viewCount': videoDetails['viewCount'],
        'thumbnails': videoDetails['thumbnail']['thumbnails'],
        'type': itemCategory[videoDetails['musicVideoType']],
      };
    }
    return null;
  }

  Future<List> getNextSongList({
    String? videoId,
    String? playlistId,
    String? params,
    int limit = 25,
    bool radio = false,
    bool shuffle = false,
  }) async {
    try {
      Map<String, dynamic> body = Map.from(context);
      body['enablePersistentPlaylistPanel'] = true;
      body['isAudioOnly'] = true;
      body['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';

      if (videoId == null && playlistId == null) {
        return [];
      }
      if (videoId != null) {
        body['videoId'] = videoId;
        playlistId ??= 'RDAMVM$videoId';
        if (!(radio || shuffle)) {
          body['watchEndpointMusicSupportedConfigs'] = {
            'watchEndpointMusicConfig': {
              'hasPersistentPlaylistPanel': true,
              'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV;',
            }
          };
        }
      }

      body['playlistId'] = playlistIdTrimmer(playlistId!);

      if (shuffle) body['params'] = 'wAEB8gECKAE%3D';
      if (radio) body['params'] = 'wAEB';
      if (params != null) body['params'] = params;
      final Map response = await sendRequest('next', body);
      dynamic contents = nav(response, [
        'contents',
        'singleColumnMusicWatchNextResultsRenderer',
        'tabbedRenderer',
        'watchNextTabbedResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'musicQueueRenderer',
        'content',
        'playlistPanelRenderer',
        'contents'
      ]);

      List result = handleContents(contents);
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Returns every song of a playlist, following `continuation` tokens.
  ///
  /// YouTube returns at most ~100 items per browse page. Android calls
  /// `YouTube.library(...).completed()`, which follows those tokens; without
  /// the loop the desktop UI silently stopped at 100 tracks.
  /// Songs already fetched in this session, keyed by playlist + account.
  /// Big playlists need ~100 continuation requests; without a cache reopening
  /// them was painfully slow.
  static final Map<String, ({List items, DateTime expiry})> _playlistCache = {};

  static void clearPlaylistCache() => _playlistCache.clear();

  Future<List> getPlaylistSongs(
    String playlistId, {
    int maxPages = 100,
    bool force = false,
    /// Called with every batch as soon as it arrives, so the UI can show the
    /// first 100 songs immediately instead of waiting for all continuations.
    void Function(List batch)? onBatch,
  }) async {
    final key = '$playlistId:${CookieStore.instance.dataSyncId ?? ''}';
    final cached = _playlistCache[key];
    if (!force && cached != null && DateTime.now().isBefore(cached.expiry)) {
      if (onBatch != null) onBatch(List.of(cached.items));
      return List.of(cached.items);
    }
    Map<String, dynamic> body = {
      "browseId": playlistId.startsWith('VL') ? playlistId : 'VL$playlistId'
    };
    var response = await sendRequest('browse', body);

    Map? shelf = nav(response, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
        ]) ??
        nav(response, [
          'contents',
          'twoColumnBrowseResultsRenderer',
          'secondaryContents',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
        ]);

    List contents = nav(shelf, ['contents']) ?? const [];
    // Continuation pages repeat songs already present in an earlier page.
    // Without deduplication a 777-song playlist showed 800 rows.
    final seen = <String>{};
    final result = <dynamic>[];
    final firstBatch = _newSongs(handleContents(contents), seen);
    result.addAll(firstBatch);
    if (onBatch != null) onBatch(List.of(firstBatch));

    // YouTube puts the continuation on `sectionListRenderer`, NOT on the
    // `musicPlaylistShelfRenderer` itself. Looking only at the shelf made
    // every big playlist stop at exactly 100 tracks.
    Map? sectionList = nav(response, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
        ]) ??
        nav(response, [
          'contents',
          'twoColumnBrowseResultsRenderer',
          'secondaryContents',
          'sectionListRenderer',
        ]);
    final rawNext = _playlistContinuation(shelf) ??
        _playlistContinuation(sectionList);
    // The token must be sent as `&ctoken=...&continuation=...`; passing the
    // bare token made YouTube ignore it and return no continuation page.
    String? next = rawNext == null ? null : getContinuationString(rawNext);
    final initialCount = result.length;
    var pages = 0;
    while (next != null && pages < maxPages) {
      final more = await getMoreItems(continuation: next);
      final items = more['items'] as List? ?? const [];
      if (items.isEmpty) break;
      final fresh = _newSongs(items, seen);
      if (fresh.isNotEmpty) {
        result.addAll(fresh);
        if (onBatch != null) onBatch(List.of(fresh));
      }
      final cont = more['continuation'];
      next = cont is String && cont.isNotEmpty ? cont : null;
      pages++;
    }
    _playlistCache[key] = (
      items: List.of(result),
      expiry: DateTime.now().add(const Duration(minutes: 10)),
    );
    if (kDebugMode && pages > 0) {
      debugPrint('[playlist] ${playlistId}: $initialCount + $pages pages = ${result.length}');
    }
    return result;
  }

  /// Diagnostic: content count and every continuation token found in a
  /// browse response, used by the runtime probe to see why a playlist stops.
  /// Pure, testable without network.
  static Map<String, dynamic> playlistDebugInfoFrom(Map response) {
    final tokens = <String>[];
    void walk(dynamic value, String path) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          if ((key == 'continuation' || key == 'token') &&
              entry.value is String &&
              (entry.value as String).isNotEmpty) {
            tokens.add('$path/$key=${(entry.value as String).substring(0, (entry.value as String).length.clamp(0, 24))}');
          }
          walk(entry.value, '$path/$key');
        }
      } else if (value is List) {
        for (var i = 0; i < value.length && i < 6; i++) {
          walk(value[i], '$path/$i');
        }
      }
    }
    walk(response, '');
    final shelf = nav(response, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
        ]) ??
        nav(response, [
          'contents',
          'twoColumnBrowseResultsRenderer',
          'secondaryContents',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
        ]);
    return {
      'keys': response.keys.toList(),
      'shelfFound': shelf != null,
      'contents': shelf == null ? 0 : (nav(shelf, ['contents']) as List?)?.length ?? 0,
      'tokens': tokens.take(12).toList(),
    };
  }

  /// Keep the first occurrence of every video. Returns only the fresh items,
  /// so the UI never renders the same track twice while pages arrive.
  static List _newSongs(List items, Set<String> seen) {
    final out = <dynamic>[];
    for (final item in items) {
      String key;
      if (item is Map) {
        final videoId = item['videoId']?.toString() ?? '';
        final setId = item['setVideoId']?.toString() ?? '';
        // The same video can reappear with a different setVideoId; the user
        // still sees it as one song, so dedupe on videoId first.
        key = videoId.isNotEmpty ? 'v:$videoId' : 's:$setId';
      } else {
        key = 'o:$item';
      }
      if (key == 'v:' || key == 's:' || !seen.add(key)) continue;
      out.add(item);
    }
    return out;
  }

  /// Continuation token can be in the old or the new InnerTube shape.
  static String? _playlistContinuation(Map? shelf) =>
      nav(shelf, ['continuations', 0, 'nextContinuationData', 'continuation']) ??
      nav(shelf, ['continuations', 0, 'continuationCommand', 'token']) ??
      nav(shelf, [
        'continuations',
        0,
        'reloadContinuationData',
        'continuation'
      ]);
}

List handleChips(chips) {
  List resultChips = [];
  for (Map chip in chips) {
    chip = chip['chipCloudChipRenderer'];
    resultChips.add({
      'title': nav(chip, ['text', 'runs', 0, 'text']),
      'selected': nav(chip, ['isSelected']) ?? false,
      'endpoint': nav(chip, ['navigationEndpoint', 'browseEndpoint']),
    });
  }
  return resultChips;
}

List<Map<String, dynamic>> handleOuterContents(List contents,
    {List? thumbnails}) {
  List<Map<String, dynamic>> results = [];
  for (Map content in contents) {
    Map<String, dynamic> result = {};
    result['contents'] = [];
    Map? musicPlaylistShelfRenderer =
        nav(content, ['musicPlaylistShelfRenderer']);
    Map? musicShelfRenderer = nav(content, ['musicShelfRenderer']);
    Map? musicCarouselShelfRenderer =
        nav(content, ['musicCarouselShelfRenderer']);
    Map? gridRenderer = nav(content, ['gridRenderer']);
    if (musicCarouselShelfRenderer != null) {
      results.add(handleMusicCarouselShelfRenderer(musicCarouselShelfRenderer));
    } else if (musicPlaylistShelfRenderer != null) {
      results.add(handleMusicPlaylistShelfRenderer(musicPlaylistShelfRenderer));
    } else if (musicShelfRenderer != null) {
      results.add(
          handleMusicShelfRenderer(musicShelfRenderer, thumbnails: thumbnails));
    } else if (gridRenderer != null) {
      results.add(handleGridRenderer(gridRenderer));
    } else {}
    results.add(result);
  }

  return results;
}

handleMusicCarouselShelfRenderer(Map item) {
  Map<String, dynamic> section = {};
  section.addAll(handleHeader(
      nav(item, ['header', 'musicCarouselShelfBasicHeaderRenderer'])));
  if (item['numItemsPerColumn'] != null &&
      (int.parse(item['numItemsPerColumn'] ?? 0)) >= 4) {
    section['viewType'] = 'COLUMN';
  } else {
    section['viewType'] = 'ROW';
  }
  section['thumbnails'] = nav(item, [
    'header',
    'musicCarouselShelfBasicHeaderRenderer',
    'thumbnail',
    'musicThumbnailRenderer',
    'thumbnail',
    'thumbnails'
  ]);
  section['contents'] = [];
  List? contents = nav(item, ['contents']);

  if (contents != null) {
    section['contents'].addAll(handleContents(contents));
  }

  return section;
}

Map<String, dynamic> handleHeader(Map header) {
  Map<String, dynamic> res = {
    'title': nav(header, ['title', 'runs', 0, 'text']),
    'strapline': nav(header, ['strapline', 'runs', 0, 'text']),
    'trailing': nav(header, ['moreContentButton']) != null
        ? {
            'text': nav(header, [
              'moreContentButton',
              'buttonRenderer',
              'text',
              'runs',
              0,
              'text'
            ]),
            'playable': nav(header, [
                  'moreContentButton',
                  'buttonRenderer',
                  'navigationEndpoint',
                  'watchPlaylistEndpoint'
                ]) !=
                null,
            'endpoint': nav(header, [
                  'moreContentButton',
                  'buttonRenderer',
                  'navigationEndpoint',
                  'watchPlaylistEndpoint'
                ]) ??
                nav(header, [
                  'moreContentButton',
                  'buttonRenderer',
                  'navigationEndpoint',
                  'browseEndpoint'
                ]),
          }
        : null,
  };

  res.removeWhere((key, val) => val == null);
  return res;
}

String playlistIdTrimmer(String playlistId) {
  if (playlistId.startsWith('VL')) {
    return playlistId.substring(2);
  } else {
    return playlistId;
  }
}
