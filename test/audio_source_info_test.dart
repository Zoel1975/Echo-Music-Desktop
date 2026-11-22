import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/audio_source_info.dart';

/// Builds the first 42 bytes of a FLAC file: magic + STREAMINFO header.
List<int> flacBytes({
  int sampleRate = 48000,
  int channels = 2,
  int bits = 24,
}) {
  final bytes = List<int>.filled(42, 0);
  bytes.setRange(0, 4, [0x66, 0x4c, 0x61, 0x43]); // fLaC
  bytes[4] = 0x00; // metadata block type 0 (STREAMINFO), not last
  bytes[7] = 34; // STREAMINFO length
  final packed = (sampleRate << 12) |
      ((channels - 1) << 9) |
      ((bits - 1) << 4);
  bytes[18] = (packed >> 24) & 0xff;
  bytes[19] = (packed >> 16) & 0xff;
  bytes[20] = (packed >> 8) & 0xff;
  bytes[21] = packed & 0xff;
  return bytes;
}

void main() {
  group('FLAC STREAMINFO', () {
    test('reads sample rate, channels and bit depth', () {
      final info = FlacStreamInfo.parse(flacBytes());
      expect(info, isNotNull);
      expect(info!.sampleRateHz, 48000);
      expect(info.channels, 2);
      expect(info.bitsPerSample, 24);
      expect(info.label, '48 kHz · 24 bit · stereo');
    });

    test('formats 44.1 kHz and mono correctly', () {
      final info = FlacStreamInfo.parse(
        flacBytes(sampleRate: 44100, channels: 1, bits: 16),
      );
      expect(info!.label, '44.1 kHz · 16 bit · mono');
    });

    test('rejects truncated, non-FLAC and error bodies', () {
      expect(FlacStreamInfo.parse(const []), isNull);
      expect(
        FlacStreamInfo.parse('{"error":"429"}'.codeUnits),
        isNull,
      );
      expect(FlacStreamInfo.parse(flacBytes().sublist(0, 20)), isNull);
      final corrupted = flacBytes()..[0] = 0x00;
      expect(FlacStreamInfo.parse(corrupted), isNull);
    });
  });

  group('formatting', () {
    test('bitrate and sample rate', () {
      expect(formatBitrate(160000), '160 kbps');
      expect(formatBitrate(1200000), '1.2 Mbps');
      expect(formatBitrate(0), isEmpty);
      expect(formatSampleRate(96000), '96 kHz');
      expect(formatSampleRate(9600), '9600 Hz');
    });

    test('YouTube mime types map to the real codec', () {
      final opus = PlaybackSourceInfo.fromStream(
        'audio/webm; codecs="opus"',
        160000,
      );
      expect(opus.format, 'Opus');
      expect(opus.label, 'Opus 160 kbps · YouTube');

      final aac = PlaybackSourceInfo.fromStream(
        'audio/mp4; codecs="mp4a.40.2"',
        128000,
      );
      expect(aac.label, 'AAC 128 kbps · YouTube');

      final mp3 = PlaybackSourceInfo.fromStream('audio/mpeg', 192000);
      expect(mp3.format, 'MP3');
    });

    test('short label hides technical details', () {
      const info = PlaybackSourceInfo(
        format: 'FLAC',
        source: 'Monochrome',
        detail: '48 kHz · 24 bit · stereo',
      );
      expect(info.shortLabel, 'FLAC · Monochrome');
      expect(info.label, 'FLAC 48 kHz · 24 bit · stereo · Monochrome');
    });
  });

  test('player wires the effective source label end to end', () {
    final player = File('lib/services/media_player.dart').readAsStringSync();
    expect(player, contains('playbackSource'));
    expect(player, contains('echoSourceFormat'));
    expect(player, contains("source: 'Monochrome'"));
    expect(player, contains("source: 'File locale'"));

    final page =
        File('lib/screens/player/player_page.dart').readAsStringSync();
    expect(page, contains('ValueListenableBuilder<PlaybackSourceInfo?>'));
    expect(page, isNot(contains("'AAC · \${q.name.toUpperCase()}'")));

    final youtube =
        File('lib/services/yt_audio_stream.dart').readAsStringSync();
    expect(youtube, contains('onResolved?.call(resolved)'));

    final mono =
        File('lib/services/monochrome_audio_source.dart').readAsStringSync();
    expect(mono, contains('onFallback?.call()'));

    final settings = File(
      'lib/screens/settings/appearance/appearance_details_page.dart',
    ).readAsStringSync();
    expect(settings, contains("'Show codec on player', 'showCodec', true"));
  });
}
