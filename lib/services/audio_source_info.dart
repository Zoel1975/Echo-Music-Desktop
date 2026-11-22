/// What is actually being played, shown under the title in the player.
///
/// The settings ceiling (`FLAC` / `HIGH` / `LOW`) is only a request: a FLAC
/// match can fall back to YouTube, and YouTube itself serves Opus or AAC
/// depending on the resolved format. This model carries the *effective*
/// source, codec and technical detail reported by the audio source itself.
class PlaybackSourceInfo {
  const PlaybackSourceInfo({
    required this.format,
    required this.source,
    this.detail,
  });

  final String format; // FLAC, Opus, AAC, MP3, Audio
  final String source; // Monochrome, YouTube, File locale
  final String? detail; // "48 kHz · 24 bit · stereo", "160 kbps", ...

  String get shortLabel => '$format · $source';
  String get label => (detail == null || detail!.isEmpty)
      ? shortLabel
      : '$format $detail · $source';

  /// Codec and bitrate from the format YouTube actually resolved.
  static PlaybackSourceInfo fromStream(
    String mimeType,
    int bitrate, {
    String source = 'YouTube',
  }) {
    final mime = mimeType.toLowerCase();
    final format = mime.contains('opus')
        ? 'Opus'
        : mime.contains('mpeg') || mime.contains('mp3')
            ? 'MP3'
            : mime.contains('mp4') || mime.contains('m4a') ||
                    mime.contains('aac')
                ? 'AAC'
                : 'Audio';
    return PlaybackSourceInfo(
      format: format,
      source: source,
      detail: formatBitrate(bitrate),
    );
  }
}

/// Human-readable bitrate, e.g. `160 kbps` or `1.2 Mbps`.
String formatBitrate(int bitsPerSecond) {
  if (bitsPerSecond <= 0) return '';
  if (bitsPerSecond >= 1000000) {
    return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
  }
  return '${(bitsPerSecond / 1000).round()} kbps';
}

/// Human-readable sample rate, e.g. `48 kHz`, `44.1 kHz` or `9600 Hz`.
String formatSampleRate(int hz) {
  if (hz <= 0) return '';
  if (hz < 10000) return '$hz Hz';
  final kHz = (hz / 1000)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$kHz kHz';
}

/// The FLAC STREAMINFO block (first metadata block in a FLAC file).
class FlacStreamInfo {
  const FlacStreamInfo({
    required this.sampleRateHz,
    required this.channels,
    required this.bitsPerSample,
  });

  final int sampleRateHz;
  final int channels;
  final int bitsPerSample;

  String get label {
    final channelLabel = channels == 2
        ? 'stereo'
        : channels == 1
            ? 'mono'
            : '$channels ch';
    return '${formatSampleRate(sampleRateHz)} · $bitsPerSample bit · $channelLabel';
  }

  /// Parses the first 42 bytes of a FLAC file (`fLaC` + STREAMINFO).
  /// Returns `null` for truncated/non-FLAC/429 error bodies.
  static FlacStreamInfo? parse(List<int> bytes) {
    if (bytes.length < 42) return null;
    if (bytes[0] != 0x66 ||
        bytes[1] != 0x4c ||
        bytes[2] != 0x61 ||
        bytes[3] != 0x43) {
      return null;
    }
    // Metadata block header: bit 7 = last block, bits 0-6 = type (0 STREAMINFO).
    if ((bytes[4] & 0x7f) != 0) return null;
    final blockLength = (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
    if (blockLength < 34 || bytes.length < 8 + 34) return null;

    // STREAMINFO: min/max block (4), min/max frame (6), then a packed 8-byte
    // field: 20 bits sample rate, 3 bits channels-1, 5 bits BPS-1.
    final o = 8 + 10;
    final packed = (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    final rate = packed >> 12;
    final channels = ((packed >> 9) & 0x7) + 1;
    final bits = ((packed >> 4) & 0x1f) + 1;
    if (rate < 8000 || rate > 768000 || channels > 8 || bits > 32) {
      return null;
    }
    return FlacStreamInfo(
      sampleRateHz: rate,
      channels: channels,
      bitsPerSample: bits,
    );
  }
}
