import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A Google Cast receiver discovered over mDNS (`_googlecast._tcp.local`).
/// This is the desktop equivalent of the devices Android lists in its
/// `CastDevicePickerSheet` through MediaRouter.
@immutable
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.model = '',
    this.kind = CastDeviceKind.unknown,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String model;
  final CastDeviceKind kind;

  /// Parse the TXT record (`id=...#cd=...#fn=...#md=...`) of a Cast service.
  static Map<String, String> parseTxt(String text) {
    final out = <String, String>{};
    // mDNS TXT values can be several length-prefixed strings glued together;
    // Cast devices use a single `k=v#k=v` string.
    for (final part in text.split('#')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      out[part.substring(0, i)] = part.substring(i + 1);
    }
    return out;
  }

  factory CastDevice.fromMdns({
    required String instanceName,
    required String host,
    required int port,
    String txt = '',
  }) {
    final props = parseTxt(txt);
    final name = props['fn'] ?? instanceName;
    final model = props['md'] ?? '';
    return CastDevice(
      id: props['id'] ?? instanceName,
      name: name,
      host: host,
      port: port > 0 ? port : 8009,
      model: model,
      kind: CastDeviceKindX.fromName(name, model),
    );
  }

  @override
  String toString() => '$name ($host:$port)';
}

/// Mirrors Android's `CastDeviceType.fromKind` keyword heuristics.
enum CastDeviceKind { tv, speaker, chromecast, unknown }

extension CastDeviceKindX on CastDeviceKind {
  static const tvKeywords = [
    'tv', 'bravia', 'webos', 'tizen', 'fire tv', 'android tv', 'google tv',
    'smart tv', 'display', 'shield', 'monitor', 'hisense', 'tcl', 'samsung',
    'lg tv', 'sony', 'vizio', 'philips',
  ];
  static const speakerKeywords = [
    'home', 'nest', 'speaker', 'audio', 'soundbar', 'max', 'mini', 'echo',
    'alexa', 'sonos', 'jbl', 'bose',
  ];
  static const castKeywords = ['chromecast', 'cast'];

  static CastDeviceKind fromName(String name, String model) {
    final s = '$name $model'.toLowerCase();
    if (tvKeywords.any(s.contains)) return CastDeviceKind.tv;
    if (speakerKeywords.any(s.contains)) return CastDeviceKind.speaker;
    if (castKeywords.any(s.contains)) return CastDeviceKind.chromecast;
    return CastDeviceKind.unknown;
  }

  String get label => switch (this) {
        CastDeviceKind.tv => 'TV',
        CastDeviceKind.speaker => 'Speaker',
        CastDeviceKind.chromecast => 'Chromecast',
        CastDeviceKind.unknown => 'Cast device',
      };

  IconData get icon => switch (this) {
        CastDeviceKind.tv => Icons.tv,
        CastDeviceKind.speaker => Icons.speaker,
        CastDeviceKind.chromecast => Icons.cast,
        CastDeviceKind.unknown => Icons.cast,
      };
}
