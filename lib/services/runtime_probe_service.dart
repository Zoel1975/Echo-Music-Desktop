import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'account_refresh.dart';
import 'audio_fallback.dart';
import 'autoeq_service.dart';
import 'cast/cast_device.dart';
import 'cast/cast_service.dart';
import 'google_login_service.dart';
import 'home_sections.dart';
import 'media_player.dart';
import '../screens/home/cubit/home_cubit.dart';
import '../screens/shell/app_shell.dart';
import 'stream_resolver.dart';
import '../screens/detail/playlist_page.dart';
import '../ytmusic/helpers.dart';
import '../ytmusic/mixins/browsing.dart';
import '../ytmusic/ytmusic.dart';
import 'cookie_store.dart';
import 'session_service.dart';
import '../utils/router.dart' as app_router;
import '../ytmusic/ytmusic.dart';

/// Loopback-only diagnostic server, enabled explicitly with `ECHO_DIAG=1`.
///
/// It exists so sign-out / session state can be verified in the *running*
/// desktop process (unit tests only see the code, not the app). It is never
/// started in a normal launch and never binds to a network interface.
class RuntimeProbeService {
  RuntimeProbeService._();

  static Future<HttpServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await _handle(request);
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
    });
    debugPrint('[runtime-probe] http://127.0.0.1:${server.port}');
    // ignore: avoid_print
    print('RUNTIME_PROBE_URL=http://127.0.0.1:${server.port}');
    return server;
  }

  static void _json(HttpResponse response, int status, Object body) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }

  static Map<String, dynamic> state() {
    final account = CookieStore.instance.account;
    return {
      'signedIn': CookieStore.instance.cookieHeader != null,
      'cookieNames': CookieStore.instance.cookies.keys.toList()..sort(),
      'hasSapisid': CookieStore.instance.cookies.containsKey('SAPISID'),
      'dataSyncId': CookieStore.instance.dataSyncId,
      'accountName': account['name'],
      'accountEmpty': account.isEmpty,
      'accountEpoch': accountEpoch.value,
      'visitorId': Hive.isBoxOpen('SETTINGS')
          ? Hive.box('SETTINGS').get('VISITOR_ID') != null
          : null,
      'audioFallback': audioFallback.value,
    };
  }

  static Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/autoeq/search' && request.method == 'GET') {
      final q = request.uri.queryParameters['q'] ?? '';
      final all = await AutoEqService.loadIndex();
      final results = AutoEqService.search(q, limit: 5);
      _json(request.response, 200, {
        'indexSize': all.length,
        'query': q,
        'results': results
            .map((p) => {'name': p.name, 'source': p.source})
            .toList(),
      });
      return;
    }
    if (path == '/state' && request.method == 'GET') {
      _json(request.response, 200, state());
      return;
    }
    if (path == '/signout' && request.method == 'POST') {
      // Exactly the call made by AccountPage's "Sign out" tile.
      await SessionService().signOut();
      _json(request.response, 200, {'after': state()});
      return;
    }
    if (path == '/seed' && request.method == 'POST') {
      // Only for testing: fabricate a session so sign-out has something to
      // remove. No real Google credentials are involved.
      await CookieStore.instance.importCookieHeader(
        'SAPISID=probe-sapisid; SID=probe-sid; LOGIN_INFO=probe',
      );
      await CookieStore.instance
          .saveAccount({'name': 'Probe User', 'signedIn': true});
      await CookieStore.instance.saveDataSyncId('PROBE_DATASYNC');
      if (Hive.isBoxOpen('SETTINGS')) {
        await Hive.box('SETTINGS').put('VISITOR_ID', 'PROBE_VISITOR');
      }
      notifyAccountChanged();
      _json(request.response, 200, {'after': state()});
      return;
    }
    if (path == '/library/playlists' && request.method == 'GET') {
      final res = await GetIt.I<YTMusic>().getLibraryPlaylists();
      final items = (res['contents'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((p) => {
                'id': p['playlistId'] ?? p['browseId'],
                'title': p['title'],
              })
          .toList();
      _json(request.response, 200, {'playlists': items});
      return;
    }
    if (path == '/library/playlists/raw' && request.method == 'GET') {
      final response = await GetIt.I<YTMusic>()
          .sendRequest('browse', {'browseId': 'FEmusic_liked_playlists'});
      final debug = BrowsingMixin.playlistDebugInfoFrom(response);
      final grid = <dynamic>[
        ...?nav(response, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0,
          'gridRenderer',
          'items',
        ]) as List?,
      ];
      debug['contentsPreview'] = jsonEncode(response['contents']).substring(
          0, (jsonEncode(response['contents']).length).clamp(0, 3000));
      debug['gridItems'] = grid
          .map((e) => {
                'playlistId': nav(e, [
                      'musicTwoRowItemRenderer',
                      'title',
                      'runs',
                      0,
                      'navigationEndpoint',
                      'browseEndpoint',
                      'browseId'
                    ]) ??
                    nav(e, [
                      'musicResponsiveListItemRenderer',
                      'playlistItemData',
                      'playlistId'
                    ]),
                'title': nav(e, [
                      'musicTwoRowItemRenderer',
                      'title',
                      'runs',
                      0,
                      'text'
                    ]) ??
                    nav(e, [
                      'musicResponsiveListItemRenderer',
                      'flexColumns',
                      0,
                      'musicResponsiveListItemFlexColumnRenderer',
                      'text',
                      'runs',
                      0,
                      'text'
                    ]),
              })
          .where((m) => m['playlistId'] != null)
          .take(15)
          .toList();
      _json(request.response, 200, debug);
      return;
    }
    if (path == '/playlist/debug' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final browseId = id.startsWith('VL') ? id : 'VL$id';
      final response =
          await GetIt.I<YTMusic>().sendRequest('browse', {'browseId': browseId});
      final debug = BrowsingMixin.playlistDebugInfoFrom(response);
      debug['id'] = browseId;
      final tailItems = nav(response, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'secondaryContents',
            'sectionListRenderer',
            'contents',
            0,
            'musicPlaylistShelfRenderer',
            'contents',
          ]) as List?;
      if (tailItems != null && tailItems.isNotEmpty) {
        final last = tailItems.last;
        debug['shelfLastKeys'] = last is Map ? last.keys.toList() : const [];
        debug['shelfLastType'] = last is Map && last.containsKey('continuationItemRenderer')
            ? 'continuationItemRenderer'
            : 'song';
        debug['shelfLastContinuation'] = last is Map
            ? nav(last, [
                'continuationItemRenderer',
                'continuationEndpoint',
                'continuationCommand',
                'token'
              ])
            : null;
      }
      final detailHeader = nav(response, [
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
      ]);
      debug['declaredCount'] = detailHeader is List
          ? detailHeader
              .map((r) => r is Map ? r['text'] : '')
              .where((t) => t != null && t.toString().isNotEmpty)
              .join(' ')
          : null;
      final header = response['header'];
      debug['headerPreview'] = header == null
          ? null
          : jsonEncode(header).substring(0, jsonEncode(header).length.clamp(0, 2500));
      debug['header'] = header is Map
          ? {
              'title': nav(header, [
                'musicResponsiveHeaderRenderer',
                'title',
                'runs',
                0,
                'text'
              ]),
              'subtitle': nav(header, [
                'musicResponsiveHeaderRenderer',
                'secondSubtitle',
                'runs'
              ]) is List
                  ? (nav(header, [
                          'musicResponsiveHeaderRenderer',
                          'secondSubtitle',
                          'runs'
                        ]) as List)
                      .map((r) => r is Map ? r['text'] : '')
                      .join('')
                  : null,
            }
          : null;
      _json(request.response, 200, debug);
      return;
    }
    if (path == '/playlist/continue' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final browseId = id.startsWith('VL') ? id : 'VL$id';
      final yt = GetIt.I<YTMusic>();
      final first = await yt.sendRequest('browse', {'browseId': browseId});
      final token = nav(first, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'secondaryContents',
            'sectionListRenderer',
            'continuations',
            0,
            'nextContinuationData',
            'continuation',
          ]) ??
          nav(first, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'continuations',
            0,
            'nextContinuationData',
            'continuation',
          ]);
      if (token == null) {
        _json(request.response, 200, {'error': 'no token'});
        return;
      }
      final cont = '&ctoken=$token&continuation=$token';
      final more = await yt.getMoreItems(continuation: cont);
      final raw = await yt.sendRequest('browse', {'browseId': 'FEmusic_home'},
          additionalParams: cont);
      final sl = raw['continuationContents'] is Map
          ? raw['continuationContents']['sectionListContinuation']
          : null;
      final slContents = sl is Map ? sl['contents'] as List? : null;
      _json(request.response, 200, {
        'tokenLength': token.toString().length,
        'items': (more['items'] as List?)?.length ?? 0,
        'moreContinuation': more['continuation'] != null,
        'rawKeys': raw.keys.toList(),
        'continuationKeys': raw['continuationContents'] is Map
            ? (raw['continuationContents'] as Map).keys.toList()
            : const [],
        'sectionContents': slContents?.length ?? 0,
        'renderers': slContents
            ?.map((c) => c is Map ? c.keys.toList() : const [])
            .toList(),
        'shelfLens': slContents
            ?.map((c) => (c is Map
                    ? nav(c, ['musicPlaylistShelfRenderer', 'contents']) as List?
                    : null)
                ?.length)
            .toList(),
      });
      return;
    }
    if (path == '/playlist/view' && request.method == 'POST') {
      final id = request.uri.queryParameters['id'] ?? '';
      app_router.router.push('/playlist', extra: {'playlistId': id});
      _json(request.response, 200, {'opened': id});
      return;
    }
    if (path == '/playlist/play-row' && request.method == 'POST') {
      final index = int.tryParse(request.uri.queryParameters['index'] ?? '0') ?? 0;
      final songs = OnlinePlaylistPage.songs;
      if (songs == null || songs.isEmpty) {
        _json(request.response, 200, {'error': 'no playlist open'});
        return;
      }
      final next = index.clamp(0, songs.length - 1);
      await GetIt.I<MediaPlayer>().playAll(songs, index: next);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _json(request.response, 200, {
        'playlistSongs': songs.length,
        'index': next,
        'current': GetIt.I<MediaPlayer>().currentSongNotifier.value?.id,
        'queue': GetIt.I<MediaPlayer>().songList.length,
      });
      return;
    }
    if (path == '/playlist/play-twice' && request.method == 'POST') {
      final songs = OnlinePlaylistPage.songs;
      if (songs == null || songs.isEmpty) {
        _json(request.response, 200, {'error': 'no playlist open'});
        return;
      }
      final mp = GetIt.I<MediaPlayer>();
      await Future.wait([
        mp.playAll(songs, index: 0),
        mp.playAll(songs, index: 10),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _json(request.response, 200, {
        'queue': mp.songList.length,
        'current': mp.currentSongNotifier.value?.id,
        'expected': songs[10]['videoId'],
        'error': mp.playbackError.value,
        'playing': mp.player.playing,
      });
      return;
    }
    if (path == '/playlist/ui' && request.method == 'GET') {
      _json(request.response, 200, {
        'songs': OnlinePlaylistPage.songCount,
        'unique': OnlinePlaylistPage.uniqueCount,
        'loading': OnlinePlaylistPage.isLoading,
        'queue': GetIt.I<MediaPlayer>().songList.length,
      });
      return;
    }
    if (path == '/playlist/continue-shelf' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final browseId = id.startsWith('VL') ? id : 'VL$id';
      final yt = GetIt.I<YTMusic>();
      final first = await yt.sendRequest('browse', {'browseId': browseId});
      final shelf = nav(first, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'secondaryContents',
            'sectionListRenderer',
            'contents',
            0,
            'musicPlaylistShelfRenderer',
          ]) as Map?;
      final token = BrowsingMixin.songsContinuation(shelf);
      if (token == null) {
        _json(request.response, 200, {'error': 'no shelf token'});
        return;
      }
      final cont = '&ctoken=$token&continuation=$token';
      final more = await yt.getMoreItems(continuation: cont);
      final raw = await yt.sendRequest('browse', {'browseId': 'FEmusic_home'},
          additionalParams: cont);
      final containers = raw['continuationContents'];
      _json(request.response, 200, {
        'tokenLength': token.length,
        'items': (more['items'] as List?)?.length ?? 0,
        'continuation': more['continuation'] != null,
        'rawKeys': raw.keys.toList(),
        'containerKeys': containers is Map ? containers.keys.toList() : const [],
        'preview': jsonEncode(raw['onResponseReceivedActions'] ?? containers)
            .substring(
                0,
                jsonEncode(raw['onResponseReceivedActions'] ?? containers)
                    .length
                    .clamp(0, 1800)),
      });
      return;
    }
    if (path == '/playlist/count' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final force = request.uri.queryParameters['force'] == '1';
      final sw = Stopwatch()..start();
      final songs =
          await GetIt.I<YTMusic>().getPlaylistSongs(id, force: force);
      final expected = id.startsWith('VL') ? id.substring(2) : id;
      var foreign = 0;
      var withId = 0;
      for (final song in songs) {
        if (song is! Map) continue;
        final raw = nav(song, [
              'navigationEndpoint',
              'watchEndpoint',
              'playlistId',
            ]) ??
            nav(song, [
              'overlay',
              'musicItemThumbnailOverlayRenderer',
              'content',
              'musicPlayButtonRenderer',
              'playNavigationEndpoint',
              'watchEndpoint',
              'playlistId',
            ]) ??
            song['playlistId'];
        if (raw == null || raw.toString().isEmpty) continue;
        withId++;
        final p = raw.toString();
        final normalized = p.startsWith('VL') ? p.substring(2) : p;
        if (normalized != expected) foreign++;
      }
      _json(request.response, 200, {
        'id': id,
        'count': songs.length,
        'withPlaylistId': withId,
        'foreign': foreign,
        'filteredForeignRaw': BrowsingMixin.lastFilteredForeign,
        'ms': sw.elapsedMilliseconds,
        'forced': force,
      });
      return;
    }
    if (path == '/home/state' && request.method == 'GET') {
      final state = HomeCubit.lastState;
      final sections = state is HomeSuccess
          ? state.sections
              .map((s) => (s is Map ? s['title'] : null)?.toString())
              .toList()
          : <String?>[];
      _json(request.response, 200, {
        'config': HomeSectionsConfig.load().encode(),
        'state': state.runtimeType.toString(),
        'titles': sections,
      });
      return;
    }
    if (path == '/home/config' && request.method == 'POST') {
      final raw = request.uri.queryParameters['order'] ?? '';
      final order = raw.split(',').where((s) => s.isNotEmpty).toList();
      final config = HomeSectionsConfig.decode(order);
      await config.save();
      HomeSectionsConfig.onChange?.call();
      _json(request.response, 200, {
        'saved': config.encode(),
        'refreshed': HomeSectionsConfig.onChange != null,
      });
      return;
    }
    if (path == '/nav' && request.method == 'GET') {
      _json(request.response, 200, {
        'branch': AppShell.currentBranchIndex,
      });
      return;
    }
    if (path == '/current' && request.method == 'GET') {
      final song = GetIt.I<MediaPlayer>().currentSongNotifier.value;
      _json(request.response, 200, {
        'videoId': song?.id,
        'title': song?.title,
        'artist': song?.artist,
      });
      return;
    }
    if (path == '/watch-page' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final body = await StreamResolver.instance.debugWatchPage(id);
      final matches = <String>[];
      for (final r in [
        r'PLAYER_JS_URL.{0,120}',
        r'jsUrl.{0,120}',
        r'player[^" ]{0,80}\.js',
      ]) {
        matches.addAll(RegExp(r).allMatches(body).take(3).map((m) => m.group(0) ?? ''));
      }
      _json(request.response, 200, {
        'length': body.length,
        'matches': matches,
        'head': body.substring(0, body.length.clamp(0, 600)),
      });
      return;
    }
    if (path == '/age-capture' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final seconds = int.tryParse(request.uri.queryParameters['seconds'] ?? '20') ?? 20;
      final captured = await GoogleLoginService()
          .captureStreamUrl(id, timeout: Duration(seconds: seconds));
      _json(request.response, 200, {
        'captured': captured != null,
        'url': captured?.url.substring(0, captured.url.length.clamp(0, 80)),
      });
      return;
    }
    if (path == '/player-raw' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final raw = await StreamResolver.instance.debugPlayer(id);
      final formats = raw['streamingData']?['adaptiveFormats'] as List? ?? const [];
      _json(request.response, 200, {
        'status': raw['playabilityStatus']?['status'],
        'reason': raw['playabilityStatus']?['reason'],
        'assetsJs': raw['assets']?['js'],
        'playerJsUrl': raw['streamingData']?['playerUrl'],
        'formatCount': formats.length,
        'firstFormatKeys': formats.isEmpty || formats.first is! Map
            ? const []
            : (formats.first as Map).keys.toList(),
        'hasCipher': formats.any((f) => f is Map && f['signatureCipher'] != null),
        'hasUrl': formats.any((f) => f is Map && f['url'] != null),
      });
      return;
    }
    if (path == '/resolve' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ??
          GetIt.I<MediaPlayer>().currentSongNotifier.value?.id ??
          '';
      try {
        final stream = await StreamResolver.instance.resolve(id);
        _json(request.response, 200, {
          'videoId': id,
          'client': stream.client,
          'mimeType': stream.mimeType,
          'bitrate': stream.bitrate,
          'contentLength': stream.contentLength,
          'url': stream.url.substring(0, stream.url.length.clamp(0, 80)),
        });
      } catch (e) {
        _json(request.response, 200, {'videoId': id, 'error': e.toString()});
      }
      return;
    }
    if (path == '/play' && request.method == 'POST') {
      final id = request.uri.queryParameters['id'] ?? 'dQw4w9WgXcQ';
      await GetIt.I<MediaPlayer>().playSong({
        'videoId': id,
        'title': 'Probe Song',
        'artists': [
          {'name': 'Probe'}
        ],
        'duration': 210000,
      });
      _json(request.response, 200, {'playing': id});
      return;
    }
    if (path == '/cast/state' && request.method == 'GET') {
      final cast = GetIt.I<CastService>();
      _json(request.response, 200, {
        'devices': cast.devices.value
            .map((d) => {
                  'name': d.name,
                  'host': d.host,
                  'port': d.port,
                  'kind': d.kind.label,
                })
            .toList(),
        'connected': cast.connected.value?.name,
        'status': cast.status.value,
        'isConnected': cast.isCasting,
        'transportId': cast.client.transportId,
        'mediaSessionId': cast.client.mediaSessionId,
      });
      return;
    }
    if (path == '/cast/media' && request.method == 'GET') {
      final cast = GetIt.I<CastService>();
      final status = await cast.client.mediaStatus();
      final media = status.isEmpty ? cast.client.lastMediaStatus.value : status;
      final first = media['status'];
      final item = first is List && first.isNotEmpty && first.first is Map
          ? Map<String, dynamic>.from(first.first as Map)
          : media;
      _json(request.response, 200, {
        'mediaSessionId': cast.client.mediaSessionId,
        'playing': cast.client.playing.value,
        'playerState': item['playerState'],
        'contentId': item['media'] is Map ? item['media']['contentId'] : null,
        'title': item['media'] is Map && item['media']['metadata'] is Map
            ? item['media']['metadata']['title']
            : null,
        'status': media,
      });
      return;
    }
    if (path == '/cast/scan' && request.method == 'GET') {
      final cast = GetIt.I<CastService>();
      await cast.scan();
      _json(request.response, 200, {
        'devices': cast.devices.value
            .map((d) => {'name': d.name, 'host': d.host, 'port': d.port})
            .toList(),
        'status': cast.status.value,
      });
      return;
    }
    if (path == '/cast/connect' && request.method == 'POST') {
      final cast = GetIt.I<CastService>();
      final host = request.uri.queryParameters['host'];
      final matches =
          cast.devices.value.where((d) => host == null || d.host == host).toList();
      if (matches.isEmpty) {
        _json(request.response, 404, {'error': 'device not found', 'host': host});
        return;
      }
      await cast.connect(matches.first);
      _json(request.response, 200, {
        'connected': cast.connected.value?.name,
        'status': cast.status.value,
      });
      return;
    }
    if (path == '/goto' && request.method == 'POST') {
      final route = request.uri.queryParameters['path'] ?? '/';
      app_router.router.go(route);
      _json(request.response, 200, {'route': route});
      return;
    }
    if (path == '/push' && request.method == 'POST') {
      // Same navigation the Settings tiles use, so Back can be verified.
      final route = request.uri.queryParameters['path'] ?? '/';
      app_router.router.push(route);
      _json(request.response, 200, {'pushed': route});
      return;
    }
    if (path == '/back' && request.method == 'POST') {
      final popped = app_router.router.canPop();
      if (popped) app_router.router.pop();
      _json(request.response, 200, {'popped': popped});
      return;
    }
    if (path == '/library' && request.method == 'GET') {
      final signedIn = CookieStore.instance.cookieHeader != null;
      try {
        final res = await GetIt.I<YTMusic>().getLibraryPlaylists();
        _json(request.response, 200, {
          'signedIn': signedIn,
          'contents': (res['contents'] as List?)?.length ?? 0,
          'continuation': res['continuation']?.toString(),
        });
      } catch (e) {
        _json(request.response, 200, {
          'signedIn': signedIn,
          'error': e.toString(),
        });
      }
      return;
    }
    _json(request.response, 404, {'error': 'unknown endpoint', 'path': path});
  }
}
