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

  /// Android `InnerTube.browse(continuation = token)`: the token goes in the
  /// POST body. The old desktop code put it in the query string, which only
  /// worked for the "related" token and silently returned nothing for the
  /// real playlist-songs token.
  Future<Map<String, dynamic>> getMoreItems({
    continuation = '',
    String? expectedPlaylistId,
  }) async {
    String? token;
    if (continuation.startsWith('&')) {
      final params = Uri.splitQueryString(continuation.substring(1));
      token = params['ctoken'] ?? params['continuation'];
    } else if (continuation.isNotEmpty) {
      token = continuation;
    }
    final response = token != null
        ? await sendRequest('browse', {'continuation': token})
        : await sendRequest('browse', {'browseId': 'FEmusic_home'},
            additionalParams: continuation);
    final containers = response['continuationContents'];
    if (containers is! Map) {
      // Playlist-shelf continuations answer with
      // onResponseReceivedActions[0].appendContinuationItemsAction.continuationItems.
      final actions = response['onResponseReceivedActions'];
      final items = actions is List && actions.isNotEmpty
          ? nav(actions.first, [
              'appendContinuationItemsAction',
              'continuationItems',
            ]) as List?
          : null;
      if (items == null) return {'items': const [], 'continuation': null};
      final nextToken = songsContinuation({'contents': items});
      final mine = expectedPlaylistId == null
          ? items
          : items.where((e) => belongsToPlaylist(e, expectedPlaylistId)).toList();
      lastFilteredForeign += items.length - mine.length;
      return {
        'items': handleContents(mine),
        'continuation':
            nextToken == null ? null : getContinuationString(nextToken),
      };
    }

    // Playlist continuations come back as `sectionListContinuation`, while
    // search/library shelves use `musicPlaylistShelfContinuation` or
    // `musicShelfContinuation`. Support all of them.
    Map? shelf = containers['musicPlaylistShelfContinuation'] as Map? ??
        containers['musicShelfContinuation'] as Map?;
    Map? outer = containers['sectionListContinuation'] as Map?;
    Map? inner;
    if (shelf == null && outer != null) {
      inner = nav(outer, ['contents', 0]) as Map?;
      shelf = inner?['musicPlaylistShelfRenderer'] as Map? ??
          inner?['musicShelfRenderer'] as Map? ??
          outer;
    }
    if (shelf == null) return {'items': const [], 'continuation': null};

    List contents = nav(shelf, ['contents']) as List? ?? const [];
    // Never use sectionList-level continuations here: they are "related".
    final continuationString = songsContinuation(shelf) ??
        songsContinuation(outer) ??
        songsContinuation(inner);
    final mine = expectedPlaylistId == null
        ? contents
        : contents.where((e) => belongsToPlaylist(e, expectedPlaylistId)).toList();
    lastFilteredForeign += contents.length - mine.length;
    return {
      'items': handleContents(mine),
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

  /// Diagnostic: how many raw items were rejected as foreign in the last load.
  static int lastFilteredForeign = 0;

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
    lastFilteredForeign = 0;
    var response = await sendRequest('browse', body);
    final declared = declaredSongCount(response);

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
    final expectedId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
    final rawFirst = contents
        .where((item) => belongsToPlaylist(item, expectedId))
        .toList();
    lastFilteredForeign += contents.length - rawFirst.length;
    final firstBatch = _newSongs(handleContents(rawFirst), seen, expectedId);
    result.addAll(firstBatch);
    if (onBatch != null) onBatch(List.of(firstBatch));

    // YouTube puts the continuation on `sectionListRenderer`, NOT on the
    // `musicPlaylistShelfRenderer` itself. Looking only at the shelf made
    // every big playlist stop at exactly 100 tracks.
    // Android's `songsContinuation`: ONLY from inside the playlist shelf.
    // `sectionListRenderer.continuations` is the "related videos" stream in
    // Android (`PlaylistPage.related`) and must never be used for songs.
    String? rawNext = songsContinuation(shelf);
    // The token must be sent as `&ctoken=...&continuation=...`; passing the
    // bare token made YouTube ignore it and return no continuation page.
    // If YouTube already declared the full length and the first page covers
    // it, never follow the token into recommended videos.
    if (declared != null && result.length >= declared) rawNext = null;
    String? next = rawNext == null ? null : getContinuationString(rawNext);
    final initialCount = result.length;
    var pages = 0;
    while (next != null && pages < maxPages) {
      final more = await getMoreItems(
          continuation: next, expectedPlaylistId: expectedId);
      final items = more['items'] as List? ?? const [];
      if (items.isEmpty) break;
      final fresh = _newSongs(items, seen, expectedId);
      if (fresh.isNotEmpty) {
        result.addAll(fresh);
        if (onBatch != null) onBatch(List.of(fresh));
      }
      // Stop at the number of tracks YouTube says this playlist contains.
      if (declared != null && result.length >= declared) break;
      final cont = more['continuation'];
      next = cont is String && cont.isNotEmpty ? cont : null;
      pages++;
    }
    // A continuation page can add up to 6 songs past the declared length.
    if (declared != null && result.length > declared) {
      result.removeRange(declared, result.length);
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

  /// Song count YouTube itself declares in the playlist header, e.g.
  /// "129 tracce" / "129 songs". Used as a stop condition: the continuation
  /// token keeps going into unrelated recommended videos after the playlist
  /// ends, which made the UI add hundreds of foreign tracks.
  static int? declaredSongCount(Map response) {
    final runs = nav(response, [
      'contents',
      'twoColumnBrowseResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'sectionListRenderer',
      'contents',
      0,
      'musicEditablePlaylistDetailHeaderRenderer',
      'header',
      'musicResponsiveHeaderRenderer',
      'secondSubtitle',
      'runs',
    ]) ??
        nav(response, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0,
          'musicDetailHeaderRenderer',
          'secondSubtitle',
          'runs',
        ]);
    final texts = <String>[];
    if (runs is List) {
      for (final run in runs) {
        final text = run is Map ? run['text']?.toString() : null;
        if (text != null && text.isNotEmpty) texts.add(text);
      }
    }
    if (texts.isEmpty) return null;
    final joined = texts.join(' ');
    final match = RegExp(
      r'(\d[\d.,\s]*)\s*(tracce|traccia|brani|canzoni|songs?|lieder|lied|pistes?|canciones?|canción|曲|首)',
      caseSensitive: false,
    ).firstMatch(joined);
    if (match == null) return null;
    return int.tryParse(match.group(1)!.replaceAll(RegExp(r'[.,\s]'), ''));
  }

  /// Keep the first occurrence of every video. Returns only the fresh items,
  /// so the UI never renders the same track twice while pages arrive.
  static List _newSongs(
    List items,
    Set<String> seen, [
    String? expectedPlaylistId,
  ]) {
    final out = <dynamic>[];
    for (final item in items) {
      // Continuation pages can contain "recommended" videos that are NOT in
      // this playlist. When YouTube exposes the playlist id, require a match.
      if (expectedPlaylistId != null && item is Map) {
        final rawId = nav(item, [
              'navigationEndpoint',
              'watchEndpoint',
              'playlistId',
            ]) ??
            nav(item, [
              'overlay',
              'musicItemThumbnailOverlayRenderer',
              'content',
              'musicPlayButtonRenderer',
              'playNavigationEndpoint',
              'watchEndpoint',
              'playlistId',
            ]) ??
            nav(item, ['playlistItemData', 'playlistId']) ??
            item['playlistId'];
        if (rawId != null && rawId.toString().isNotEmpty) {
          final id = rawId.toString();
          final normalized = id.startsWith('VL') ? id.substring(2) : id;
          if (normalized != expectedPlaylistId) continue;
        }
      }
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

  /// True when a RAW playlist renderer belongs to [expectedId]. Must run
  /// before `handleContents`, which drops the nested playlist id fields.
  static bool belongsToPlaylist(dynamic renderer, String expectedId) {
    if (renderer is! Map) return true;
    final inner = renderer['musicResponsiveListItemRenderer'] ??
        renderer['playlistPanelVideoRenderer'] ??
        renderer;
    if (inner is! Map) return true;
    final raw = nav(inner, ['navigationEndpoint', 'watchEndpoint', 'playlistId']) ??
        nav(inner, [
          'overlay',
          'musicItemThumbnailOverlayRenderer',
          'content',
          'musicPlayButtonRenderer',
          'playNavigationEndpoint',
          'watchEndpoint',
          'playlistId',
        ]) ??
        nav(inner, ['playlistItemData', 'playlistId']) ??
        inner['playlistId'];
    if (raw == null || raw.toString().isEmpty) return true;
    final id = raw.toString();
    final normalized = id.startsWith('VL') ? id.substring(2) : id;
    return normalized == expectedId;
  }

  /// Android `MusicShelfRenderer.getContinuation()` / `List<Continuation>.getContinuation()`:
  /// the songs token is a `continuationItemRenderer` at the END of the shelf's
  /// contents, or the shelf's own `continuations`. The `sectionListRenderer`
  /// token is for related videos and is deliberately ignored here.
  static String? songsContinuation(Map? shelf) {
    if (shelf == null) return null;
    final contents = shelf['contents'];
    if (contents is List) {
      for (final item in contents) {
        final token = nav(item, [
          'continuationItemRenderer',
          'continuationEndpoint',
          'continuationCommand',
          'token',
        ]);
        if (token is String && token.isNotEmpty) return token;
      }
    }
    return nav(shelf, ['continuations', 0, 'nextContinuationData', 'continuation']) ??
        nav(shelf, ['continuations', 0, 'continuationCommand', 'token']) ??
        nav(shelf, [
          'continuations',
          0,
          'reloadContinuationData',
          'continuation'
        ]);
  }
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
