import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'cast_device.dart';
import 'cast_protocol.dart';

/// A live CastV2 session with one receiver. Port of Android's
/// `CastConnectionHandler`: connect -> GET_STATUS -> LAUNCH (Default Media
/// Receiver) -> open the app channel -> LOAD/PLAY/PAUSE/SEEK/volume.
class CastClient {
  CastClient({this.heartbeat = const Duration(seconds: 5)});

  final Duration heartbeat;

  Socket? _socket;
  StreamSubscription<List<int>>? _reader;
  Timer? _heartbeatTimer;
  Timer? _launchPoll;
  Uint8List _buffer = Uint8List(0);
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  CastDevice? device;
  String transportId = '';
  String sessionId = '';
  int mediaSessionId = 0;
  int _requestId = 0;

  final ValueNotifier<String> state = ValueNotifier<String>('disconnected');
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);
  /// Latest MEDIA_STATUS payload seen on the wire (LOAD reply or broadcast).
  /// More reliable than re-querying: some TVs answer GET_STATUS with no id.
  final ValueNotifier<Map<String, dynamic>> lastMediaStatus =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});

  bool get isConnected => _socket != null;

  int get nextRequestId => ++_requestId;

  Future<void> connect(CastDevice target) async {
    await disconnect();
    state.value = 'connecting';
    device = target;
    Exception? lastError;
    // Modern Cast devices use TLS on 8009; older ones speak plain TCP. Some
    // TVs only expose 8443. Try all of them, in that order.
    for (final attempt in [
      () => SecureSocket.connect(target.host, target.port,
          onBadCertificate: (_) => true),
      () => Socket.connect(target.host, target.port),
      () => SecureSocket.connect(target.host, CastProtocol.tlsPort,
          onBadCertificate: (_) => true),
    ]) {
      try {
        _socket = await attempt().timeout(const Duration(seconds: 5));
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    final socket = _socket;
    if (socket == null) {
      state.value = 'error';
      throw lastError ?? const SocketException('Cannot reach Cast device');
    }
    _reader = socket.listen(_onData, onError: (e) => _lost(e), onDone: () => _lost(null));
    _heartbeatTimer = Timer.periodic(heartbeat, (_) {
      send(CastProtocol.receiverId, CastProtocol.heartbeatNamespace,
          {'type': 'PING'});
    });

    // Open the platform channel (required before any other namespace).
    send(CastProtocol.receiverId, CastProtocol.connectionNamespace,
        CastProtocol.connect());

    var status = await send<Map<String, dynamic>>(
      CastProtocol.receiverId,
      CastProtocol.receiverNamespace,
      CastProtocol.getStatus(nextRequestId),
    );
    _readApp(status);

    // If our media receiver is not running, launch it and poll RECEIVER_STATUS
    // until the device reports its transport/session ids. TVs can be slow (or
    // busy closing another sender's app), so retry LAUNCH once.
    for (var attempt = 0; attempt < 2 && transportId.isEmpty; attempt++) {
      await send(
        CastProtocol.receiverId,
        CastProtocol.receiverNamespace,
        CastProtocol.launch(nextRequestId),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (transportId.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        status = await send<Map<String, dynamic>>(
          CastProtocol.receiverId,
          CastProtocol.receiverNamespace,
          CastProtocol.getStatus(nextRequestId),
        );
        _readApp(status);
      }
    }
    if (transportId.isEmpty) {
      state.value = 'error';
      throw StateError('Cast device did not start the media receiver');
    }
    // Open the application channel (same as pychromecast's destination channel).
    send(transportId, CastProtocol.connectionNamespace, CastProtocol.connect());
    state.value = 'connected';
  }

  void _readApp(Map<String, dynamic>? status) {
    final apps = status?['status']?['applications'] as List?;
    if (kDebugMode && apps != null) {
      debugPrint('[cast] apps=${apps.map((a) => (a as Map)['appId']).toList()} '
          'transport=$transportId');
    }
    if (apps == null || apps.isEmpty) return;
    // Never reuse somebody else's app session (e.g. the TV's Spotify Cast
    // session): LOAD would be sent to the wrong receiver and silently ignored.
    // Only the Default Media Receiver can play our relay URL. A TV can report
    // several running apps, so search all of them.
    final app = apps.whereType<Map<String, dynamic>>().firstWhere(
          (a) => a['appId']?.toString() == CastProtocol.defaultMediaAppId,
          orElse: () => <String, dynamic>{},
        );
    if (app.isEmpty) return;
    transportId = (app['transportId'] ?? app['sessionId'] ?? '').toString();
    sessionId = (app['sessionId'] ?? transportId).toString();
  }

  /// Send a Cast message. When the payload has a `requestId`, the returned
  /// future completes with the matching response (or an empty map on timeout).
  Future<T> send<T>(
    String destination,
    String namespace,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final socket = _socket;
    if (socket == null) throw StateError('Cast device not connected');
    final requestId = payload['requestId'] as int?;
    Completer<Map<String, dynamic>>? completer;
    if (requestId != null) {
      completer = Completer<Map<String, dynamic>>();
      _pending[requestId] = completer;
    }
    socket.add(CastProtocol.frame(
      sourceId: CastProtocol.senderId,
      destinationId: destination,
      namespace: namespace,
      payload: payload,
    ));
    if (completer == null) return <String, dynamic>{} as T;
    final result = await completer.future
        .timeout(timeout, onTimeout: () => <String, dynamic>{});
    _pending.remove(requestId);
    return result as T;
  }

  Future<Map<String, dynamic>> load({
    required String contentId,
    required String title,
    String? artist,
    String? imageUrl,
    String contentType = 'audio/mpeg',
    int? durationMs,
  }) async {
    if (transportId.isEmpty) throw StateError('No Cast app session');
    final rid = nextRequestId;
    final res = await send<Map<String, dynamic>>(
      transportId,
      CastProtocol.mediaNamespace,
      CastProtocol.load(
        requestId: rid,
        sessionId: sessionId,
        contentId: contentId,
        contentType: contentType,
        title: title,
        artist: artist,
        imageUrl: imageUrl,
        durationMs: durationMs,
      ),
    );
    _readMediaStatus(res);
    // Many receivers (including BRAVIA TVs) answer LOAD with an empty
    // acknowledgement and only publish the media session in a later
    // MEDIA_STATUS. Query it explicitly, like pychromecast's MediaController.
    for (var i = 0; i < 5 && mediaSessionId == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _readMediaStatus(await mediaStatus());
    }
    playing.value = true;
    return res;
  }

  /// Query the running media session (`GET_STATUS` on the media namespace).
  Future<Map<String, dynamic>> mediaStatus() async {
    if (transportId.isEmpty) return <String, dynamic>{};
    return send<Map<String, dynamic>>(
      transportId,
      CastProtocol.mediaNamespace,
      {'type': 'GET_STATUS', 'requestId': nextRequestId},
    );
  }

  Future<void> play() => _command('PLAY');

  Future<void> pause() => _command('PAUSE');

  Future<void> stop() => _command('STOP');

  Future<void> seek(Duration position) {
    if (mediaSessionId == 0) return _command('PLAY');
    return send(
      transportId,
      CastProtocol.mediaNamespace,
      CastProtocol.playbackCommand('SEEK',
          requestId: nextRequestId,
          mediaSessionId: mediaSessionId,
          positionMs: position.inMilliseconds),
    );
  }

  Future<void> setVolume(double level) => send(
        CastProtocol.receiverId,
        CastProtocol.receiverNamespace,
        CastProtocol.setVolume(nextRequestId, level.clamp(0.0, 1.0)),
      );

  Future<void> _command(String type) async {
    if (transportId.isEmpty || mediaSessionId == 0) return;
    final res = await send<Map<String, dynamic>>(
      transportId,
      CastProtocol.mediaNamespace,
      CastProtocol.playbackCommand(type,
          requestId: nextRequestId, mediaSessionId: mediaSessionId),
    );
    if (type == 'PLAY') playing.value = true;
    if (type == 'PAUSE' || type == 'STOP') playing.value = false;
    _readMediaStatus(res);
  }

  void _readMediaStatus(Map<String, dynamic>? payload) {
    final raw = payload?['status'];
    Map<String, dynamic>? first;
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      first = Map<String, dynamic>.from(raw.first as Map);
    } else if (raw is Map) {
      first = Map<String, dynamic>.from(raw);
    }
    if (first == null) return;
    lastMediaStatus.value = first;
    final id = first['mediaSessionId'];
    if (id is num) mediaSessionId = id.toInt();
    final playerState = first['playerState']?.toString() ?? '';
    if (playerState.isNotEmpty) playing.value = playerState == 'PLAYING';
  }

  void _onData(List<int> chunk) {
    final merged = Uint8List(_buffer.length + chunk.length)
      ..setAll(0, _buffer)
      ..setAll(_buffer.length, chunk);
    _buffer = merged;
    while (_buffer.length >= 4) {
      final len = (_buffer[0] << 24) |
          (_buffer[1] << 16) |
          (_buffer[2] << 8) |
          _buffer[3];
      if (len <= 0 || len > 1024 * 1024 || _buffer.length < 4 + len) break;
      final body = _buffer.sublist(4, 4 + len);
      _buffer = _buffer.sublist(4 + len);
      CastMessage message;
      try {
        message = CastProtocol.decode(body);
      } catch (_) {
        continue;
      }
      _handle(message);
    }
  }

  void _handle(CastMessage message) {
    final data = message.json;
    final type = data['type']?.toString() ?? '';
    if (type == 'PING') {
      send(message.sourceId, CastProtocol.heartbeatNamespace, {'type': 'PONG'});
      return;
    }
    if (message.namespace == CastProtocol.receiverNamespace &&
        type == 'RECEIVER_STATUS') {
      _readApp(data);
    }
    if (message.namespace == CastProtocol.mediaNamespace &&
        type == 'MEDIA_STATUS') {
      _readMediaStatus(data);
    }
    final requestId = data['requestId'];
    if (requestId is int) {
      final c = _pending.remove(requestId);
      if (c != null && !c.isCompleted) c.complete(data);
      return;
    }
    // Some devices omit requestId on broadcasts; the first waiter gets it.
    if (_pending.isNotEmpty && (type == 'RECEIVER_STATUS' || type == 'MEDIA_STATUS')) {
      final first = _pending.entries.first;
      _pending.remove(first.key);
      if (!first.value.isCompleted) first.value.complete(data);
    }
  }

  void _lost(Object? error) {
    if (_socket == null) return;
    debugPrint('[cast] connection lost: $error');
    state.value = 'disconnected';
    _pending.values.forEach((c) {
      if (!c.isCompleted) c.complete(<String, dynamic>{});
    });
    _pending.clear();
    _reader?.cancel();
    _reader = null;
    _socket?.close();
    _socket = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _launchPoll?.cancel();
    transportId = '';
    mediaSessionId = 0;
    playing.value = false;
  }

  Future<void> disconnect() async {
    _lost(null);
    state.value = 'disconnected';
  }
}
