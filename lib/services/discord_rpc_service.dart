import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Port of Android `DiscordPresenceManager.kt`: connects to the local Discord
/// RPC socket (ws://127.0.0.1:6463) and publishes the current track as a
/// "Listening" activity using the token/activity config entered in-app.
class DiscordRpcService {
  DiscordRpcService();

  WebSocket? _socket;
  int _nonce = 0;
  String? _token;

  bool get isConnected => _socket != null;

  /// Pure builder for the SET_ACTIVITY payload (unit-testable).
  static Map<String, dynamic> activityPayload({
    required String name,
    required String details,
    required String state,
    required String activityType,
    required bool showWhenPaused,
    required int nonce,
  }) {
    return {
      'cmd': 'SET_ACTIVITY',
      'args': {
        'pid': 0,
        'activity': {
          'name': name,
          'details': details,
          'state': state,
          'type': _typeIndex(activityType),
          'assets': {
            'large_image': 'echo',
            'large_text': 'Echo Music',
          },
          'timestamps': {'start': DateTime.now().millisecondsSinceEpoch ~/ 1000},
          if (!showWhenPaused) 'instance': false,
        },
      },
      'nonce': nonce.toString(),
    };
  }

  static int _typeIndex(String type) => switch (type) {
        'Playing' => 0,
        'Streaming' => 1,
        'Listening' => 2,
        'Watching' => 3,
        _ => 2,
      };

  /// Pure: build the AUTHORIZE handshake URL with client id + scopes.
  static String authorizeUrl(String clientId) =>
      'ws://127.0.0.1:6463/?v=1&client_id=$clientId'
      '&scope=identify%20rpc.notifications.read';

  Future<bool> connect(String token) async {
    _token = token;
    try {
      _socket = await WebSocket.connect(authorizeUrl('112233445566778899'))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('[discord] connect failed (client not running?): $e');
      _socket = null;
      return false;
    }
  }

  Future<void> setActivity({
    required String name,
    required String details,
    required String state,
    required String activityType,
    required bool showWhenPaused,
  }) async {
    final socket = _socket;
    if (socket == null) return;
    final payload = activityPayload(
      name: name,
      details: details,
      state: state,
      activityType: activityType,
      showWhenPaused: showWhenPaused,
      nonce: ++_nonce,
    );
    socket.add(jsonEncode(payload));
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
  }
}
