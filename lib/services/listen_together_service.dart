import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Current playback state shared with a Listen Together room.
@immutable
class ListenState {
  const ListenState({
    required this.username,
    required this.songId,
    required this.title,
    required this.positionMs,
    required this.playing,
    required this.updatedAt,
  });

  final String username;
  final String songId;
  final String title;
  final int positionMs;
  final bool playing;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'username': username,
        'songId': songId,
        'title': title,
        'positionMs': positionMs,
        'playing': playing,
        'updatedAt': updatedAt,
      };

  factory ListenState.fromJson(Map<String, dynamic> j) => ListenState(
        username: j['username']?.toString() ?? '',
        songId: j['songId']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        positionMs: (j['positionMs'] as num?)?.toInt() ?? 0,
        playing: j['playing'] == true,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Real port of Android `ListenTogether*` protocol: a lightweight LAN HTTP
/// room where the host publishes playback state and guests poll it. Uses the
/// room server URL + username entered in-app. No external credentials needed.
class ListenTogetherService {
  ListenTogetherService();

  HttpServer? _server;
  ListenState? _lastState;
  String _room = 'echo';

  /// Android's Listen Together auto-approval preference. When false, guest
  /// updates are ignored until explicitly approved by the host.
  bool autoApprove = true;
  final Set<String> _approvedUsers = <String>{};
  final Set<String> _pendingUsers = <String>{};
  Set<String> get pendingUsers => Set.unmodifiable(_pendingUsers);
  void approve(String username) {
    _approvedUsers.add(username);
    _pendingUsers.remove(username);
  }

  bool get isHosting => _server != null;
  ListenState? get state => _lastState;

  static const int port = 8900;

  Future<bool> startHosting(String username) async {
    if (_server != null) return true;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handle);
      debugPrint('[listen-together] hosting room on :$port');
      return true;
    } catch (e) {
      debugPrint('[listen-together] host failed: $e');
      return false;
    }
  }

  void publishState(ListenState state) => _lastState = state;

  void _handle(HttpRequest request) {
    final isPost = request.method == 'POST';
    if (isPost) {
      utf8.decoder.bind(request).join().then((body) {
        try {
          final incoming =
              ListenState.fromJson(jsonDecode(body) as Map<String, dynamic>);
          final allowed = autoApprove || _approvedUsers.contains(incoming.username);
          if (!allowed) {
            _pendingUsers.add(incoming.username);
            debugPrint('[listen-together] pending join: ${incoming.username}');
          } else {
            _lastState = incoming;
          }
        } catch (_) {}
      });
    }
    final body = jsonEncode(_lastState?.toJson() ?? const {});
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('application', 'json')
      ..write(body);
    request.response.close();
  }

  /// Join a room: POST our state then GET the host's current state.
  Future<ListenState?> joinAndSync(String serverUrl, ListenState mine) async {
    try {
      final base = serverUrl.trim().isEmpty
          ? 'http://127.0.0.1:$port'
          : serverUrl.trim();
      final client = HttpClient();
      final postReq = await client.postUrl(Uri.parse(base));
      postReq.headers.contentType = ContentType('application', 'json');
      postReq.write(jsonEncode(mine.toJson()));
      final postRes = await postReq.close().timeout(const Duration(seconds: 5));
      await postRes.drain<void>();
      final getReq = await client.getUrl(Uri.parse(base));
      final getRes = await getReq.close().timeout(const Duration(seconds: 5));
      final body = await utf8.decoder.bind(getRes).join();
      client.close();
      if (body.isEmpty || body == '{}') return null;
      return ListenState.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[listen-together] join failed: $e');
      return null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
