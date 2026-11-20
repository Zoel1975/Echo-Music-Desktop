import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Device-link protocol "tramite YouTube Music + stato di riproduzione" (YT Music
/// playback state). The desktop repeatedly broadcasts a small announce on the
/// existing discovery UDP channel; any peer on the same Wi-Fi with the same
/// YouTube/Google account fingerprint sees it — that fingerprint IS the link.

/// Proto name of the announce datagram (first field, used for filtering).
const String announceProto = 'echo-desktop-link';

/// UDP probe a peer sends to the existing discovery port to query the desktop
/// for its current playback state (the YT Music state-of-playback signal).
const String probePlaying = 'ECHO_MUSIC_PLAYING';

/// Pure: SHA-256 fingerprint of the signed-in Google/YouTube account. Two
/// devices on the same account share this fingerprint; empty when logged out.
String accountFingerprint(Map<String, String> cookies) {
  if (cookies.isEmpty) return '';
  final pairs = cookies.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
  return sha256.convert(utf8.encode(pairs.join(';'))).toString();
}

/// One announce datagram. `account` is the [accountFingerprint].
@immutable
class DeviceLinkAnnounce {
  const DeviceLinkAnnounce({
    required this.id,
    required this.name,
    required this.account,
    required this.updatedAt,
    this.playing = false,
    this.songId = '',
    this.title = '',
  });

  final String id;
  final String name;
  final String account;
  final bool playing;
  final String songId;
  final String title;
  final int updatedAt;

  Map<String, Object?> toJson() => {
        'proto': announceProto,
        'id': id,
        'name': name,
        'account': account,
        'playing': playing,
        'songId': songId,
        'title': title,
        'updatedAt': updatedAt,
      };

  /// Returns null unless this bytes are an announce with the right proto.
  static DeviceLinkAnnounce? fromBytes(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (j['proto'] != announceProto) return null;
      final id = (j['id'] as String?) ?? '';
      return DeviceLinkAnnounce(
        id: id.isEmpty ? 'desktop' : id,
        name: (j['name'] ?? 'Echo Desktop').toString(),
        account: (j['account'] ?? '').toString(),
        playing: j['playing'] == true,
        songId: (j['songId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));
}

/// Body of the reply to a [probePlaying] — the current playback state.
Map<String, Object?> playingStateJson(
  bool playing, {
  String songId = '',
  String title = '',
}) =>
    {
      'proto': announceProto,
      'playing': playing,
      'songId': songId,
      'title': title,
    };
