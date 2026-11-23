import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart'
    as ffmpeg_kit_flutter_new_audio;
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

import 'account_refresh.dart';
import 'audio_fallback.dart';
import 'automix_debug.dart';
import 'ffmpeg_audio_encoder.dart';
import 'autoeq_service.dart';
import 'beat_analyzer_service.dart';
import 'comments_service.dart';
import 'cast/cast_device.dart';
import 'cast/cast_service.dart';
import 'google_login_service.dart';
import 'home_sections.dart';
import 'media_player.dart';
import 'monochrome_service.dart';
import 'po_token_minter.dart';
import 'settings_manager.dart';
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

  /// One second of silence in PCM WAV, for the real FFmpeg export probe.
  static List<int> _probeWav() {
    const rate = 44100;
    const samples = rate;
    final data = samples * 2;
    final bytes = <int>[];
    void ascii(String s) => bytes.addAll(s.codeUnits);
    void word(int v) {
      bytes.addAll([v & 0xff, (v >> 8) & 0xff]);
    }

    void dword(int v) {
      bytes.addAll([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    }

    ascii('RIFF');
    dword(36 + data);
    ascii('WAVEfmt ');
    dword(16); // PCM chunk size
    word(1); // PCM
    word(1); // mono
    dword(rate);
    dword(rate * 2); // byte rate
    word(2); // block align
    word(16); // bits per sample
    ascii('data');
    dword(data);
    bytes.addAll(List<int>.filled(data, 0));
    return bytes;
  }

  /// 12 s of 120 BPM clicks, to verify the Automix beat analysis end to end.
  static List<int> _probeClickWav() {
    const rate = 22050;
    const seconds = 35;
    final samples = List<double>.filled(rate * seconds, 0.0);
    for (var beat = 0; beat < seconds * 2; beat++) {
      final start = (beat * 0.5 * rate).round();
      for (var i = 0; i < (0.06 * rate).round(); i++) {
        final envelope =
            math.exp(-i / (rate * 0.012));
        samples[start + i] =
            math.sin(2 * math.pi * 180 * i / rate) * envelope * 0.9;
      }
    }
    final data = samples.length * 2;
    final bytes = <int>[];
    void ascii(String s) => bytes.addAll(s.codeUnits);
    void word(int v) => bytes.addAll([v & 0xff, (v >> 8) & 0xff]);
    void dword(int v) =>
        bytes.addAll([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    ascii('RIFF');
    dword(36 + data);
    ascii('WAVEfmt ');
    dword(16);
    word(1);
    word(1);
    dword(rate);
    dword(rate * 2);
    word(2);
    word(16);
    ascii('data');
    dword(data);
    for (final s in samples) {
      word((s.clamp(-1.0, 1.0) * 32767).round());
    }
    return bytes;
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
    if (path == '/monochrome/search' && request.method == 'GET') {
      final q = request.uri.queryParameters['q'] ?? '';
      final tracks = await MonochromeService.search(q, limit: 5);
      _json(request.response, 200, {
        'query': q,
        'count': tracks.length,
        'tracks': tracks
            .map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'artist': t.artist,
                  'isrc': t.isrc,
                  'url': t.streamUrl,
                })
            .toList(),
      });
      return;
    }
    if (path == '/monochrome/stream' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? '';
      final req = http.Request('GET', Uri.parse('${MonochromeService.base}/track/$id'))
        ..headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
          'Referer': 'https://monochrome.st/',
          'Range': 'bytes=0-1023',
        });
      final res = await http.Client().send(req).timeout(const Duration(seconds: 30));
      final bytes = await res.stream.toList();
      final first = bytes.isEmpty ? <int>[] : bytes.first.sublist(0, 4);
      _json(request.response, 200, {
        'id': id,
        'status': res.statusCode,
        'contentRange': res.headers[HttpHeaders.contentRangeHeader],
        'firstBytes': String.fromCharCodes(first),
        'isFlac': first.length == 4 && String.fromCharCodes(first) == 'fLaC',
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
          .whereType<Map>()
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
    if (path == '/probe/auth' && request.method == 'GET') {
      final yt = GetIt.I<YTMusic>();
      await yt.refreshHeaders();
      final hdrs = Map<String, String>.from(yt.headers);
      final cookie = hdrs['cookie'] ?? hdrs['Cookie'] ?? '';
      final cookieNames = cookie
          .split('; ')
          .where((p) => p.contains('='))
          .map((p) => p.substring(0, p.indexOf('=')))
          .toList();
      final body = jsonEncode({
        ...yt.context,
        'browseId': 'FEmusic_liked_playlists',
      });
      final uri = Uri.parse(
        'https://music.youtube.com/youtubei/v1/browse?alt=json'
        '&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
      );
      Future<Map<String, dynamic>> trial(
          String label, Map<String, String> h) async {
        try {
          final res = await http.post(uri, headers: h, body: body);
          final text = res.body;
          return {
            'label': label,
            'status': res.statusCode,
            'grid': text.contains('gridRenderer'),
            'shelf': text.contains('musicShelfRenderer'),
            'signIn': text.contains('signInEndpoint'),
            'len': text.length,
          };
        } catch (e) {
          return {'label': label, 'error': e.toString()};
        }
      }

      final results = <Map<String, dynamic>>[];
      results.add(await trial('current', hdrs));
      results.add(await trial('noSecure',
          {...hdrs, 'cookie': cookie.split('; ').where((p) => !p.startsWith('__')).join('; ')}));
      results.add(await trial(
          'xOrigin', {...hdrs, 'X-Origin': 'https://music.youtube.com'}));
      results.add(await trial('noAuth', {...hdrs}..remove('Authorization')));
      final authCookies = cookie
          .split('; ')
          .where((p) {
            final name = p.split('=').first;
            return const {'SID', 'HSID', 'SSID', 'APISID', 'SAPISID'}
                .contains(name);
          })
          .join('; ');
      results.add(await trial('authCookiesOnly', {...hdrs, 'cookie': authCookies}));

      _json(request.response, 200, {
        'headerNames': hdrs.keys.toList()..sort(),
        'cookieCount': cookieNames.length,
        'cookieNames': cookieNames..sort(),
        'authPrefix': hdrs['Authorization']?.substring(
            0, hdrs['Authorization']!.length.clamp(0, 24)),
        'authUser': hdrs['X-Goog-AuthUser'],
        'visitorLen': hdrs['X-Goog-Visitor-Id']?.length,
        'contextUser': (yt.context['user'] as Map?)?['onBehalfOfUser'],
        'results': results,
      });
      return;
    }
    if (path == '/potoken/mint' && request.method == 'POST') {
      final id = request.uri.queryParameters['id'] ?? 'esHBHhbDQh4';
      try {
        final token = await PoTokenMinter.instance.mint(id);
        if (token != null) {
          StreamResolver.instance.savePoToken(
            id,
            player: token,
            gvs: token,
          );
        }
        _json(request.response, 200, {
          'ok': token != null,
          'length': token?.length ?? 0,
          'preview': token?.substring(0, 12) ?? '',
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/potoken/capture' && request.method == 'POST') {
      final id = request.uri.queryParameters['id'] ?? '';
      try {
        final captured =
            await GoogleLoginService().capturePoToken(id);
        if (captured == null) {
          _json(request.response, 200, {'captured': false});
          return;
        }
        if ((captured.poToken ?? '').isNotEmpty ||
            (captured.gvsToken ?? '').isNotEmpty) {
          StreamResolver.instance.savePoToken(
            id,
            player: captured.poToken,
            gvs: captured.gvsToken,
          );
        }
        _json(request.response, 200, {
          'captured': true,
          'playerToken': (captured.poToken ?? '').isNotEmpty,
          'gvsToken': (captured.gvsToken ?? '').isNotEmpty,
          'streamUrl': captured.streamUrl != null,
          'headers': captured.headers.length,
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/automix/harmonic-test' && request.method == 'POST') {
      final settings = GetIt.I<SettingsManager>();
      settings.crossfadeEnabled = true;
      settings.automixBeatAlign = true;
      settings.automixHarmonicMix = true;
      final player = GetIt.I<MediaPlayer>();
      Map<String, dynamic> song(String id, String title) => {
            'videoId': id,
            'title': title,
            'artists': [
              {'name': 'Probe'}
            ],
            'duration': 210000,
          };
      await player.playSong(song('dQw4w9WgXcQ', 'Harmony OUT'));
      for (final id in ['2Vv-BfVoq4g', 'kJQP7kiw5Fk', 'JgpJVI3tDbY']) {
        await player.addToQueue(song(id, 'Harmony candidate $id'));
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final duration = player.player.duration ?? const Duration(seconds: 210);
      final target = duration - const Duration(seconds: 45);
      await player.player.seek(target > Duration.zero ? target : Duration.zero);
      _json(request.response, 200, {
        'queued': player.player.sequence.length,
        'targetMs': target.inMilliseconds,
      });
      return;
    }
    if (path == '/queue/crossfade-test' && request.method == 'POST') {
      final settings = GetIt.I<SettingsManager>();
      settings.crossfadeEnabled = true;
      settings.automixBeatAlign = true;
      final player = GetIt.I<MediaPlayer>();
      Map<String, dynamic> song(String id, String title) => {
            'videoId': id,
            'title': title,
            'artists': [
              {'name': 'Probe'}
            ],
            'duration': 210000,
          };
      await player.playSong(song('dQw4w9WgXcQ', 'Probe A'));
      await player.addToQueue(song('2Vv-BfVoq4g', 'Probe B'));
      await Future<void>.delayed(const Duration(seconds: 2));
      final duration = player.player.duration ?? const Duration(seconds: 210);
      final target = duration - const Duration(seconds: 30);
      await player.player.seek(target > Duration.zero ? target : Duration.zero);
      _json(request.response, 200, {
        'durationMs': duration.inMilliseconds,
        'seekMs': target.inMilliseconds,
        'queueLength': player.player.sequence.length,
      });
      return;
    }
    if (path == '/settings/extra' && request.method == 'POST') {
      final key = request.uri.queryParameters['key'] ?? '';
      final value = request.uri.queryParameters['value'] ?? '';
      if (key.isEmpty) {
        _json(request.response, 400, {'error': 'missing key'});
        return;
      }
      final settings = GetIt.I<SettingsManager>();
      final numeric = num.tryParse(value);
      if (numeric != null && value.contains('.')) {
        settings.setExtra<double>(key, numeric.toDouble());
      } else if (numeric != null) {
        settings.setExtra<int>(key, numeric.toInt());
      } else if (value == 'true' || value == 'false') {
        settings.setExtra<bool>(key, value == 'true');
      } else {
        settings.setExtra<String>(key, value);
      }
      _json(request.response, 200, {
        'key': key,
        'value': settings.settings['EXTRA_$key'],
      });
      return;
    }
    if (path == '/settings/crossfade' && request.method == 'POST') {
      final enabled = request.uri.queryParameters['enabled'] != '0';
      final settings = GetIt.I<SettingsManager>();
      settings.crossfadeEnabled = enabled;
      settings.automixBeatAlign = enabled;
      final seconds = num.tryParse(
          request.uri.queryParameters['seconds'] ?? '')?.toDouble();
      if (seconds != null) settings.crossfadeDuration = seconds;
      _json(request.response, 200, {
        'crossfadeEnabled': settings.crossfadeEnabled,
        'automixBeatAlign': settings.automixBeatAlign,
        'duration': settings.crossfadeDuration,
      });
      return;
    }
    if (path == '/player/debug-exact' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? 'esHBHhbDQh4';
      final resolver = StreamResolver.instance;
      final results = <Map<String, dynamic>>[];
      final removeKeys = [
        '',
        'BODY_TOKEN',
        'BODY_USER',
        'X-Goog-Api-Format-Version',
        'X-Origin',
        'Authorization',
        'Accept-Language',
        'X-Goog-Visitor-Id',
      ];
      for (final remove in removeKeys) {
        final headers = resolver.buildHeaders(YtPlayerClient.webRemix, music: true);
        if (remove.isNotEmpty && !remove.startsWith('BODY_')) {
          headers.remove(remove);
        }
        final body = resolver.buildBody(YtPlayerClient.webRemix, id);
        if (remove == 'BODY_TOKEN') body.remove('serviceIntegrityDimensions');
        if (remove == 'BODY_USER') {
          (body['context'] as Map).remove('user');
        }
        try {
          final r = await http
              .post(
                Uri.parse(
                    'https://music.youtube.com/youtubei/v1/player?prettyPrint=false'),
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20));
          Map<String, dynamic>? decoded;
          try {
            decoded = jsonDecode(r.body) as Map<String, dynamic>;
          } catch (_) {}
          results.add({
            'removed': remove.isEmpty ? 'none' : remove,
            'status': r.statusCode,
            'playability': decoded?['playabilityStatus']?['status'],
            'reason': decoded?['playabilityStatus']?['reason'] ??
                decoded?['error']?['message'],
            'hasTopToken': body.containsKey('serviceIntegrityDimensions'),
          });
        } catch (e) {
          results.add({'removed': remove, 'error': e.toString()});
        }
      }
      _json(request.response, 200, {'results': results});
      return;
    }
    if (path == '/player/debug-matrix' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? 'esHBHhbDQh4';
      const oldVersion = '1.20260213.01.00';
      const newVersion = '1.20260707.12.00';
      const oldKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
      final results = <Map<String, dynamic>>[];
      for (final version in [oldVersion, newVersion]) {
        for (final useKey in [true, false]) {
          for (final withAuth in [true, false]) {
            final headers = <String, String>{
              'Content-Type': 'application/json',
              'User-Agent': YtPlayerClient.webRemix.userAgent,
              'X-Youtube-Client-Name': '67',
              'X-Youtube-Client-Version': version,
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
              'X-Goog-Visitor-Id':
                  'CgtaUm9ja1ZpZGVvLXByb2JlGJexrYUFOgMI',
            };
            if (withAuth) {
              final auth = CookieStore.instance
                  .authorizationHeaderFor('https://music.youtube.com');
              if (auth != null) headers['Authorization'] = auth;
              headers['X-Goog-AuthUser'] = '0';
            }
            final cookie = CookieStore.instance.cookieHeader;
            if (cookie != null) headers['Cookie'] = cookie;
            final body = {
              'context': {
                'client': {
                  'clientName': 'WEB_REMIX',
                  'clientVersion': version,
                  'hl': 'en',
                  'gl': 'US',
                  'visitorData': headers['X-Goog-Visitor-Id'],
                },
              },
              'videoId': id,
              'contentCheckOk': true,
              'racyCheckOk': true,
            };
            final query = useKey ? '?alt=json&key=$oldKey' : '?prettyPrint=false';
            try {
              final r = await http
                  .post(
                    Uri.parse(
                        'https://music.youtube.com/youtubei/v1/player$query'),
                    headers: headers,
                    body: jsonEncode(body),
                  )
                  .timeout(const Duration(seconds: 20));
              Map<String, dynamic>? decoded;
              try {
                decoded = jsonDecode(r.body) as Map<String, dynamic>;
              } catch (_) {}
              results.add({
                'version': version == oldVersion ? 'old' : 'new',
                'key': useKey,
                'auth': withAuth,
                'status': r.statusCode,
                'playability': decoded?['playabilityStatus']?['status'],
                'reason': decoded?['playabilityStatus']?['reason'] ??
                    decoded?['error']?['message'],
              });
            } catch (e) {
              results.add({
                'version': version == oldVersion ? 'old' : 'new',
                'key': useKey,
                'auth': withAuth,
                'error': e.toString(),
              });
            }
          }
        }
      }
      _json(request.response, 200, {'results': results});
      return;
    }
    if (path == '/player/debug-age' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? 'esHBHhbDQh4';
      final resolver = StreamResolver.instance;
      final out = <Map<String, dynamic>>[];
      for (final client in [
        YtPlayerClient.webRemix,
        YtPlayerClient.webCreator,
        YtPlayerClient.webEmbedded,
      ]) {
        final headers = resolver.buildHeaders(client);
        final body = resolver.buildBody(client, id, visitorData: null);
        final endpoint = client.name == 'WEB_CREATOR'
            ? 'https://studio.youtube.com/youtubei/v1/player'
            : client.name == 'WEB_REMIX'
                ? 'https://music.youtube.com/youtubei/v1/player'
                : 'https://www.youtube.com/youtubei/v1/player';
        try {
          final r = await http
              .post(
                Uri.parse('$endpoint?prettyPrint=false'),
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20));
          final preview = r.body.length > 400 ? r.body.substring(0, 400) : r.body;
          out.add({
            'client': client.name,
            'status': r.statusCode,
            'origin': headers['Origin'],
            'auth': headers.containsKey('Authorization'),
            'visitor': headers['X-Goog-Visitor-Id']?.toString().length ?? 0,
            'token': body.containsKey('serviceIntegrityDimensions'),
            'body': preview,
          });
        } catch (e) {
          out.add({'client': client.name, 'error': e.toString()});
        }
      }
      _json(request.response, 200, {'results': out});
      return;
    }
    if (path == '/comments/test' && request.method == 'GET') {
      final id = request.uri.queryParameters['id'] ?? 'dQw4w9WgXcQ';
      try {
        final page = await CommentsService.instance.fetch(id);
        _json(request.response, 200, {
          'count': page.comments.length,
          'next': page.nextToken != null,
          'first': page.comments.isEmpty
              ? null
              : {
                  'author': page.comments.first.author,
                  'text': page.comments.first.text.substring(
                      0, page.comments.first.text.length.clamp(0, 80)),
                },
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/recognition/dshow' && request.method == 'GET') {
      try {
        final session = await ffmpeg_kit_flutter_new_audio.FFmpegKit.execute(
          '-hide_banner -f dshow -list_devices true -i dummy',
        );
        final logs = await session.getLogsAsString();
        _json(request.response, 200, {
          'exit': (await session.getReturnCode())?.toString(),
          'log': logs.length > 1500 ? logs.substring(logs.length - 1500) : logs,
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/automix/state' && request.method == 'GET') {
      _json(request.response, 200, AutomixDebug.instance.toJson());
      return;
    }
    if (path == '/beat/analyze-song' && request.method == 'POST') {
      final id = request.uri.queryParameters['id'] ?? 'dQw4w9WgXcQ';
      try {
        final result = await BeatAnalyzerService.analyzeSong({
          'videoId': id,
          'title': 'Probe',
          'duration': 210000,
        });
        _json(request.response, 200, {
          'bpm': result?.bpm,
          'key': result?.keyLabel,
          'mixInMs': result?.mixInMs,
          'mixOutMs': result?.mixOutMs,
          'confidence': result?.confidence,
          'headBytes': BeatAnalyzerService.lastHeadBytes,
          'headError': BeatAnalyzerService.lastHeadError,
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/beat/analyze' && request.method == 'POST') {
      final dir = Directory.systemTemp;
      final wav = '${dir.path}${Platform.pathSeparator}echo_beat_probe.wav';
      try {
        File(wav).writeAsBytesSync(_probeClickWav());
        final beat = await BeatAnalyzerService.analyzePath(
          'probe-click-120-v4',
          wav,
          durationMs: 35000,
        );
        _json(request.response, 200, {
          'bpm': beat?.bpm,
          'offsetMs': beat?.firstBeatOffsetMs,
          'confidence': beat?.confidence,
          'mixInMs': beat?.mixInMs,
          'mixOutMs': beat?.mixOutMs,
          'key': beat?.keyLabel,
          'headBytes': BeatAnalyzerService.lastHeadBytes,
          'headError': BeatAnalyzerService.lastHeadError,
          'tailBytes': BeatAnalyzerService.lastTailBytes,
          'tailError': BeatAnalyzerService.lastTailError,
        });
      } catch (e) {
        _json(request.response, 500, {'error': e.toString()});
      }
      return;
    }
    if (path == '/crossfade/test' && request.method == 'POST') {
      final settings = GetIt.I<SettingsManager>();
      settings.crossfadeEnabled = true;
      settings.crossfadeDuration = 3;
      final player = GetIt.I<MediaPlayer>();
      await player.playSong({
        'videoId': 'dQw4w9WgXcQ',
        'title': 'Crossfade A',
        'artists': [
          {'name': 'Probe'}
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await player.playSong({
        'videoId': '2Vv-BfVoq4g',
        'title': 'Crossfade B',
        'artists': [
          {'name': 'Probe'}
        ],
      });
      final samples = <Map<String, dynamic>>[];
      for (var i = 0; i < 16; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        samples.add({
          't': (i + 1) * 150,
          'main': player.player.volume.round().toDouble() / 100,
          'out': (player.diagnosticOutVolume * 100).round().toDouble() / 100,
          'handoff': player.diagnosticHandoffRunning,
          'fade': player.diagnosticCrossfading,
        });
      }
      _json(request.response, 200, {
        'enabled': settings.crossfadeEnabled,
        'samples': samples,
      });
      return;
    }
    if (path == '/export/mp3' && request.method == 'POST') {
      final dir = Directory.systemTemp;
      final input = '${dir.path}${Platform.pathSeparator}echo_probe.wav';
      final output = '${dir.path}${Platform.pathSeparator}echo_probe.mp3';
      try {
        File(input).writeAsBytesSync(_probeWav());
        final bytes = <int>[];
        await FfmpegAudioEncoder().encode(
          inputPath: input,
          outputPath: output,
          bitrateKbps: 128,
          durationMs: 1000,
          onProgress: (p) {
            if (p != null) bytes.add((p * 100).round());
          },
        );
        final mp3 = File(output).readAsBytesSync();
        _json(request.response, 200, {
          'ok': true,
          'size': mp3.length,
          'magic': mp3.take(3).toList(),
          'progressSamples':
              bytes.length > 5 ? bytes.sublist(bytes.length - 5) : bytes,
        });
      } catch (e) {
        _json(request.response, 500, {'ok': false, 'error': e.toString()});
      }
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
