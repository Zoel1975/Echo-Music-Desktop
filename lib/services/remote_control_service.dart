import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'cookie_store.dart';
import 'device_link_announcement.dart';
import 'media_player.dart';
import 'settings_manager.dart';
import 'yt_audio_stream.dart';

/// A small LAN HTTP "remote control" for Echo — the desktop counterpart of
/// Android's Cast/remote-control features. Another device on the same Wi-Fi can
/// open the URL in a browser to see the current track and control playback.
///
/// Device linking is done via the YouTube Music playback state: every ~2s the
/// desktop broadcasts a [DeviceLinkAnnounce] (id, account fingerprint, current
/// song, playing flag) on the UDP discovery channel. Peers with the same
/// account fingerprint are linked automatically. [probePlaying] returns the
/// live playback state to any peer that asks.
class RemoteControlService {
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  String? _url;
  String? _host;
  Timer? _announceTimer;
  final List<DeviceLinkAnnounce> _announces = [];

  String? get url => _url;
  bool get isRunning => _server != null;
  List<DeviceLinkAnnounce> get deviceLinkAnnounces =>
      List.unmodifiable(_announces);

  /// Map of account fingerprint → most recent announce for that account
  /// (a linked device). Easiest entry point for linking/matching.
  Map<String, DeviceLinkAnnounce> get linkedByAccount => {
        for (final a in _announces)
          if (a.account.isNotEmpty) a.account: a,
      };

  /// Add (or refresh) a linked announce. Public so other surfaces can feed
  /// announces into the view.
  void addLinkedAnnounce(DeviceLinkAnnounce announce) {
    if (announce.id.isEmpty) return;
    _announces.removeWhere((a) => a.id == announce.id);
    _announces.add(announce);
  }

  static const int port = 8899;
  static const int discoveryPort = 8898;
  /// Probe string a controller broadcasts to find Echo on the LAN.
  static const String discoveryProbe = 'ECHO_MUSIC_DISCOVER';
  static const String deviceName = 'Echo Music (Desktop)';

  /// Stable per-install id of this desktop (used in announces and pairing).
  String get deviceLinkId {
    final settings = GetIt.I<SettingsManager>();
    final existing = settings.extra<String>(deviceLinkIdKey, '');
    if (existing.isNotEmpty) return existing;
    final fp = accountFp;
    final id =
        'echo-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}-'
        '${fp.isEmpty ? 'offline' : fp.substring(0, fp.length < 8 ? fp.length : 8)}';
    settings.setExtra<String>(deviceLinkIdKey, id);
    return id;
  }

  /// Const key used by [deviceLinkId] in the settings box.
  static const String deviceLinkIdKey = 'deviceLinkId';

  /// Account fingerprint of the signed-in Google/YouTube account (empty when
  /// logged out or hive not ready) — the "YouTube Music" side of device linking.
  String get accountFp {
    try {
      return accountFingerprint(CookieStore.instance.cookies);
    } catch (_) {
      return '';
    }
  }

  /// Playback state of the desktop for peer queries.
  Map<String, Object?> playingState() {
    final mp = GetIt.I<MediaPlayer>();
    final song = mp.currentSongNotifier.value;
    return playingStateJson(mp.player.playing,
        songId: song?.id ?? '', title: song?.title ?? '');
  }

  Future<void> start() async {
    if (_server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      server.listen(_handle);
      final host = server.address.address == '0.0.0.0'
          ? await _lanIp()
          : server.address.address;
      _url = 'http://$host:$port';
      _host = host;
      debugPrint('[remote] control server at $_url');
      await _startDiscovery(host);
      _startAnnouncements();
    } catch (e) {
      debugPrint('[remote] failed to start: $e');
    }
  }

  /// Start advertising the announce datagram (YT Music playback state) every
  /// 2s on the discovery channel; peers with the same account fingerprint
  /// link to us.
  void _startAnnouncements() {
    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendAnnounce();
    });
    _sendAnnounce();
  }

  /// Broadcast one announce on the UDP discovery channel (broadcast + LAN host).
  void _sendAnnounce() {
    try {
      // MediaPlayer is registered a few ms after start() at boot; skip until ready.
      if (!GetIt.I.isRegistered<MediaPlayer>()) return;
      final mp = GetIt.I<MediaPlayer>();
      final announce = DeviceLinkAnnounce(
        id: deviceLinkId,
        name: deviceName,
        account: accountFp,
        playing: mp.player.playing,
        songId: mp.currentSongNotifier.value?.id ?? '',
        title: mp.currentSongNotifier.value?.title ?? '',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final data = announce.toBytes();
      // Broadcast only where the OS allows it: Windows rejects sends to the
      // limited broadcast address (errno 10013). Peers discover us through the
      // ECHO_MUSIC_DISCOVER probe instead, so this is not required there.
      if (!Platform.isWindows) {
        try {
          _discovery?.send(data, InternetAddress('255.255.255.255'), discoveryPort);
        } catch (_) {}
      }
      final host = _host;
      if (host != null && host != '255.255.255.255') {
        try {
          _discovery?.send(data, InternetAddress(host), discoveryPort);
        } catch (_) {}
      }
    } catch (_) {
      // Linking is best-effort: never take down the app for announces.
    }
  }

  /// UDP discovery responder: any controller sending [discoveryProbe] to the
  /// discovery port receives back the device name and its control URL, so it
  /// can be found on the LAN without manual entry (Cast-style discovery).
  Future<void> _startDiscovery(String host) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      _discovery = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        // Link-by-playback: an incoming announce — dedupe by id, expose it.
        final announce = DeviceLinkAnnounce.fromBytes(datagram.data);
        if (announce != null) {
          addLinkedAnnounce(announce);
          return;
        }
        final probe = utf8.decode(datagram.data, allowMalformed: true);
        // Peer wants our live YT Music playback state.
        if (probe.contains(probePlaying)) {
          socket.send(utf8.encode(jsonEncode(playingState())),
              datagram.address, datagram.port);
          return;
        }
        if (!probe.contains(discoveryProbe)) return;
        final reply = utf8.encode(jsonEncode({
          'device': deviceName,
          'url': _url,
          'port': port,
          // Extra fields so a peer can auto-link by account + id.
          'account': accountFp,
          'deviceId': deviceLinkId,
          'announceProto': announceProto,
        }));
        socket.send(reply, datagram.address, datagram.port);
      });
      debugPrint('[remote] discovery listening on :$discoveryPort');
    } catch (e) {
      debugPrint('[remote] discovery failed: $e');
    }
  }

  /// Use the same LAN address selection as Cast, so the remote URL is
  /// reachable from the phone instead of pointing at a WSL virtual adapter.
  Future<String> _lanIp() => lanIp();

  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _discovery?.close();
    _discovery = null;
    await _server?.close(force: true);
    _server = null;
    _url = null;
  }

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    final player = GetIt.I<MediaPlayer>();
    final q = request.uri.queryParameters;
    switch (path) {
      case '/play':
        player.player.play();
      case '/pause':
        player.player.pause();
      case '/next':
        player.player.seekToNext();
      case '/previous':
        player.player.seekToPrevious();
      case '/volume':
        final v = double.tryParse(q['value'] ?? '');
        if (v != null) player.player.setVolume(v.clamp(0.0, 1.0));
      case '/seek':
        final s = int.tryParse(q['to'] ?? '');
        if (s != null) player.player.seek(Duration(milliseconds: s));
      case '/status':
      case '/device':
      case '/':
        break;
      default:
        break;
    }
    final track = player.currentSongNotifier.value;
    final playing = player.buttonState.value.name;
    final isJson = path == '/status' || path == '/device';
    final body = isJson
        ? jsonEncode(path == '/device'
            ? {
                'device': deviceName,
                'url': _url,
                'port': port,
                'discoveryPort': discoveryPort,
                'discoveryProbe': discoveryProbe,
              }
            : {
                'title': track?.title ?? '',
                'artist': track?.artist ?? '',
                'playing': playing,
                'positionMs': player.player.position.inMilliseconds,
                'volume': player.player.volume,
                'url': _url,
              })
        : _page(track?.title ?? 'Nothing playing', track?.artist ?? '', playing);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = isJson
          ? ContentType('application', 'json')
          : ContentType('text', 'html', charset: 'utf-8')
      ..write(body);
    request.response.close();
  }

  String _page(String title, String artist, String playing) => '''
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Echo Remote</title>
<style>
body{margin:0;min-height:100vh;background:#141215;color:#f2edef;font-family:system-ui,sans-serif;display:grid;place-items:center;text-align:center}
h1{font-size:1.4rem;margin:0 0 .2rem;font-weight:600}
p{color:#b9afb5;margin:0 0 2rem}
.row{display:flex;gap:1rem;justify-content:center}
a{display:inline-block;background:#262126;color:#f2edef;text-decoration:none;padding:.9rem 1.4rem;border-radius:999px}
a:hover{background:#ed5564}
small{display:block;color:#6e6268;margin-top:2rem}
</style></head><body>
<div><h1>$title</h1><p>$artist &middot; $playing</p>
<div class="row">
<a href="/previous">&#9198;</a><a href="/play">&#9654;</a>
<a href="/pause">&#10074;&#10074;</a><a href="/next">&#9197;</a>
</div><small>Echo Music remote &middot; same Wi-Fi required</small></div>
</body></html>''';
}
