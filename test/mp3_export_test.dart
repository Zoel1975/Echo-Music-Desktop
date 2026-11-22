import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/ffmpeg_audio_encoder.dart';

void main() {
  group('FFmpeg MP3 command', () {
    test('uses libmp3lame, ID3v2.3 and the requested bitrate', () {
      final args = buildMp3Args(
        inputPath: 'C:\\Music\\song.m4a',
        outputPath: 'C:\\Music\\song.mp3.part',
        bitrateKbps: 320,
        tags: {'title': 'A Song', 'artist': 'An Artist'},
      );
      expect(args, contains('-c:a'));
      expect(args, contains('libmp3lame'));
      expect(args, contains('-b:a'));
      expect(args, contains('320k'));
      expect(args, contains('-id3v2_version'));
      expect(args, contains('3'));
      expect(args, contains('-metadata'));
      expect(args, contains('title=A Song'));
      expect(args, contains('artist=An Artist'));
      expect(args.last, 'C:\\Music\\song.mp3.part');
    });

    test('clamps the bitrate to a safe range', () {
      final args = buildMp3Args(
        inputPath: 'in.m4a',
        outputPath: 'out.mp3',
        bitrateKbps: 9999,
      );
      expect(args, contains('320k'));
    });
  });

  test('MP3 export is wired through settings, menu and FFmpeg Kit', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('ffmpeg_kit_flutter_new_audio: ^3.0.0'));

    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('GetIt.I<ExportTaskQueue>()'));

    final settings =
        File('lib/services/settings_manager.dart').readAsStringSync();
    expect(settings, contains('exportBitrateKbps'));

    final queue =
        File('lib/services/export_task_queue.dart').readAsStringSync();
    expect(queue, contains('.part'));
    expect(queue, contains('enqueueSong'));
    expect(queue, contains('FfmpegAudioEncoder'));

    final modal = File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modal, contains("'Esporta in MP3'"));

    final doc = File('docs/MP3_EXPORT.md').readAsStringSync();
    expect(doc, contains('FFmpeg'));
    expect(doc, contains('LGPL'));
    expect(doc, contains('Flacora'));
  });
}
