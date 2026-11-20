import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'media_player.dart';
import 'settings_manager.dart';

/// A small LAN HTTP "remote control" for Echo — the desktop counterpart of
/// Android's Cast/remote-control features. Another device on the same Wi-Fi can
/// open the URL in a browser to see the current track and control playback.
class RemoteControlService {
  HttpServer? _server;
  String? _url;

  String? get url => _url;
  bool get isRunning => _server != null;

  static const int port = 8899;

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
      debugPrint('[remote] control server at $_url');
    } catch (e) {
      debugPrint('[remote] failed to start: $e');
    }
  }

  Future<String> _lanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final nic in interfaces) {
        for (final addr in nic.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _url = null;
  }

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    final player = GetIt.I<MediaPlayer>();
    switch (path) {
      case '/play':
        player.player.play();
      case '/pause':
        player.player.pause();
      case '/next':
        player.player.seekToNext();
      case '/previous':
        player.player.seekToPrevious();
      case '/status':
        break;
      default:
        break;
    }
    final track = player.currentSongNotifier.value;
    final playing = player.buttonState.value.name;
    final body = path == '/status'
        ? jsonEncode({
            'title': track?.title ?? '',
            'artist': track?.artist ?? '',
            'playing': playing,
            'url': GetIt.I<SettingsManager>().remoteControlEnabled ? _url : null,
          })
        : _page(track?.title ?? 'Nothing playing', track?.artist ?? '', playing);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = path == '/status'
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
