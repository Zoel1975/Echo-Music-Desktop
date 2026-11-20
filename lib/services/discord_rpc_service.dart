import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Port of Android `DiscordPresenceManager.kt`: connects to the local Discord
/// RPC WebSocket (ports 6463–6472), authenticates with the access token
/// entered in-app, and publishes the current track as a "Listening" activity.
class DiscordRpcService {
  DiscordRpcService();

  WebSocket? _socket;
  int _nonce = 0;
  String _clientId = '';
  String _token = '';
  bool _authenticated = false;

  bool get isConnected => _socket != null && _authenticated;

  /// Pure builder for the handshake URL with the user's in-app client id.
  /// Discord verifies Origin, so we send https://localhost.
  static String authorizeUrl(String clientId) =>
      'ws://127.0.0.1:6463/?v=1&client_id=${Uri.encodeComponent(clientId)}'
      '&encoding=json';

  /// Pure builder for the AUTHENTICATE command using the in-app token.
  static Map<String, dynamic> authenticatePayload({
    required String accessToken,
    required int nonce,
  }) =>
      {
        'cmd': 'AUTHENTICATE',
        'args': {'access_token': accessToken},
        'nonce': nonce.toString(),
      };

  /// Pure builder for the SET_ACTIVITY payload.
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
          'timestamps': {
            'start': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          },
          'instance': showWhenPaused,
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

  Future<bool> connect({
    required String clientId,
    required String accessToken,
  }) async {
    _clientId = clientId;
    _token = accessToken;
    if (clientId.isEmpty || accessToken.isEmpty) return false;

    // Discord may bind any port in 6463..6472.
    WebSocket? socket;
    for (var port = 6463; port <= 6472; port++) {
      try {
        socket = await WebSocket.connect(
          'ws://127.0.0.1:$port/?v=1&client_id=${Uri.encodeComponent(clientId)}'
          '&encoding=json',
          headers: {'Origin': 'https://localhost'},
        ).timeout(const Duration(seconds: 2));
        break;
      } catch (_) {
        continue;
      }
    }
    if (socket == null) {
      debugPrint('[discord] no local RPC server found on 6463-6472');
      return false;
    }
    _socket = socket;
    // Send AUTHENTICATE with the in-app token.
    socket.add(jsonEncode(authenticatePayload(
      accessToken: accessToken,
      nonce: ++_nonce,
    )));
    _authenticated = true;
    return true;
  }

  Future<void> setActivity({
    required String name,
    required String details,
    required String state,
    required String activityType,
    required bool showWhenPaused,
  }) async {
    final socket = _socket;
    if (socket == null || !_authenticated) return;
    socket.add(jsonEncode(activityPayload(
      name: name,
      details: details,
      state: state,
      activityType: activityType,
      showWhenPaused: showWhenPaused,
      nonce: ++_nonce,
    )));
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    _authenticated = false;
  }
}
