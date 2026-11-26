import 'dart:convert';
import 'dart:typed_data';

/// Minimal, dependency-free implementation of the CastV2 `CastMessage`
/// protobuf (Chromium `cast_channel.proto`) and its JSON command payloads.
///
/// Android Echo Music talks to Cast devices through the Google Play Services
/// Cast SDK. Desktop has no GMS, so we speak the same wire protocol directly:
/// a 4-byte big-endian length followed by this protobuf message.
class CastProtocol {
  static const connectionNamespace = 'urn:x-cast:com.google.cast.tp.connection';
  static const heartbeatNamespace = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const receiverNamespace = 'urn:x-cast:com.google.cast.receiver';
  static const mediaNamespace = 'urn:x-cast:com.google.cast.media';

  static const senderId = 'sender-0';
  static const receiverId = 'receiver-0';
  /// Default Media Receiver - the same receiver YouTube Music casts to when a
  /// plain audio/video URL has to be played on a TV or speaker.
  static const defaultMediaAppId = 'CC1AD845';

  static const defaultPort = 8009;
  static const tlsPort = 8443;

  static final _senderInfo = <String, dynamic>{
    'sdkType': 2,
    'version': '15.605.1.3',
    'browserVersion': '44.0.2403.30',
    'platform': 4,
    'systemVersion': 'Echo Music Desktop',
    'connectionType': 1,
  };

  CastProtocol._();

  /// Frame a JSON payload as a CastMessage ready to write to the socket.
  static Uint8List frame({
    required String sourceId,
    required String destinationId,
    required String namespace,
    required Map<String, dynamic> payload,
  }) {
    final body = encode(
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payloadUtf8: jsonEncode(payload),
    );
    final framed = Uint8List(4 + body.length);
    framed[0] = (body.length >> 24) & 0xff;
    framed[1] = (body.length >> 16) & 0xff;
    framed[2] = (body.length >> 8) & 0xff;
    framed[3] = body.length & 0xff;
    framed.setAll(4, body);
    return framed;
  }

  /// Encode the proto2 CastMessage fields we need.
  static Uint8List encode({
    required String sourceId,
    required String destinationId,
    required String namespace,
    String? payloadUtf8,
    List<int>? payloadBinary,
  }) {
    final out = <int>[];
    // protocol_version = CASTV2_1_0 (0), required field 1.
    _writeVarint(out, 0x08, 0);
    _writeString(out, 2, sourceId);
    _writeString(out, 3, destinationId);
    _writeString(out, 4, namespace);
    // payload_type = STRING (0), required field 5.
    _writeVarint(out, 0x28, 0);
    if (payloadUtf8 != null) _writeString(out, 6, payloadUtf8);
    if (payloadBinary != null) _writeBytes(out, 7, payloadBinary);
    return Uint8List.fromList(out);
  }

  /// Decode a single CastMessage body (without the 4-byte length prefix).
  static CastMessage decode(List<int> bytes) {
    var sourceId = '';
    var destinationId = '';
    var namespace = '';
    var payloadUtf8 = '';
    List<int>? payloadBinary;
    var i = 0;
    while (i < bytes.length) {
      final key = _readVarint(bytes, i);
      i = key.next;
      final field = key.value >> 3;
      final wire = key.value & 7;
      if (wire == 0) {
        final v = _readVarint(bytes, i);
        i = v.next;
        // field 1 (protocol_version) and 5 (payload_type) are enums.
      } else if (wire == 2) {
        final len = _readVarint(bytes, i);
        i = len.next;
        final end = i + len.value;
        if (end > bytes.length) break;
        final slice = bytes.sublist(i, end);
        i = end;
        switch (field) {
          case 2:
            sourceId = utf8.decode(slice, allowMalformed: true);
          case 3:
            destinationId = utf8.decode(slice, allowMalformed: true);
          case 4:
            namespace = utf8.decode(slice, allowMalformed: true);
          case 6:
            payloadUtf8 = utf8.decode(slice, allowMalformed: true);
          case 7:
            payloadBinary = slice;
        }
      } else {
        break;
      }
    }
    return CastMessage(
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payloadUtf8: payloadUtf8,
      payloadBinary: payloadBinary,
    );
  }

  static void _writeVarint(List<int> out, int tag, int value) {
    out.add(tag);
    var v = value;
    while (v >= 0x80) {
      out.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.add(v);
  }

  static void _writeString(List<int> out, int field, String value) =>
      _writeBytes(out, field, utf8.encode(value));

  static void _writeBytes(List<int> out, int field, List<int> value) {
    _writeVarint(out, (field << 3) | 2, value.length);
    out.addAll(value);
  }

  static _Varint _readVarint(List<int> bytes, int start) {
    var value = 0;
    var shift = 0;
    var i = start;
    while (i < bytes.length && shift < 63) {
      final b = bytes[i++];
      value |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return _Varint(value, i);
      shift += 7;
    }
    return _Varint(value, i);
  }

  // --- JSON payload builders -------------------------------------------------

  static Map<String, dynamic> connect() => {
        'type': 'CONNECT',
        'origin': <String, dynamic>{},
        'userAgent': 'EchoMusicDesktop',
        'senderInfo': _senderInfo,
      };

  static Map<String, dynamic> close() => {
        'type': 'CLOSE',
        'origin': <String, dynamic>{},
      };

  static Map<String, dynamic> getStatus(int requestId) =>
      {'type': 'GET_STATUS', 'requestId': requestId};

  static Map<String, dynamic> launch(int requestId) => {
        'type': 'LAUNCH',
        'appId': defaultMediaAppId,
        'requestId': requestId,
      };

  static Map<String, dynamic> load({
    required int requestId,
    required String sessionId,
    required String contentId,
    required String contentType,
    required String title,
    String? artist,
    String? imageUrl,
    int? durationMs,
  }) {
    final metadata = <String, dynamic>{
      'metadataType': 3, // MOVIE
      'title': title,
      if (artist != null && artist.isNotEmpty) 'subtitle': artist,
      if (imageUrl != null && imageUrl.isNotEmpty)
        'images': [
          {'url': imageUrl}
        ],
    };
    if (durationMs != null) metadata['duration'] = durationMs / 1000.0;
    return {
      'type': 'LOAD',
      'requestId': requestId,
      'sessionId': sessionId,
      'autoplay': true,
      'currentTime': 0,
      'media': {
        'contentId': contentId,
        'contentType': contentType,
        'streamType': 'BUFFERED',
        'metadata': metadata,
      },
    };
  }

  static Map<String, dynamic> playbackCommand(
    String type, {
    required int requestId,
    required int mediaSessionId,
    int? positionMs,
  }) =>
      {
        'type': type,
        'requestId': requestId,
        'mediaSessionId': mediaSessionId,
        if (positionMs != null)
          'seekOptions': {'position': positionMs / 1000.0},
      };

  static Map<String, dynamic> setVolume(int requestId, double level,
          {bool muted = false}) =>
      {
        'type': 'SET_VOLUME',
        'requestId': requestId,
        'volume': {'level': level, 'muted': muted},
      };
}

class CastMessage {
  const CastMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payloadUtf8,
    this.payloadBinary,
  });

  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payloadUtf8;
  final List<int>? payloadBinary;

  Map<String, dynamic> get json {
    try {
      final v = jsonDecode(payloadUtf8);
      return v is Map<String, dynamic> ? v : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class _Varint {
  const _Varint(this.value, this.next);
  final int value;
  final int next;
}
