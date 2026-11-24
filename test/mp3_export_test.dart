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

    test('forces the mp3 container for the .part temporary file', () {
      final args = buildMp3Args(
        inputPath: 'in.m4a',
        outputPath: 'out.mp3.part',
        bitrateKbps: 192,
      );
      final i = args.indexOf('-f');
      expect(i, greaterThanOrEqualTo(0));
      expect(args[i + 1], 'mp3',
          reason:
              'FFmpeg cannot infer the container from a .part extension; '
              'without this the export always fails with exit 1');
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
    expect(modal, contains('ExportFeedback.exportSong'));
    expect(modal, contains('S.of(context).ExportAsMP3'));
    expect(modal, isNot(contains('Esporta in MP3')));
    expect(modal, isNot(contains('Esportazione MP3 avviata')));

    // Export feedback must be visible and actionable: live progress plus the
    // destination file. The old flow only flashed an invisible toast.
    final feedback = File('lib/utils/export_feedback.dart').readAsStringSync();
    expect(feedback, contains('LinearProgressIndicator'));
    expect(feedback, contains('ExportSavedToFolder'));
    expect(feedback, contains('OpenFolder'));
    expect(feedback, contains('ExportFailed'));

    final doc = File('docs/MP3_EXPORT.md').readAsStringSync();
    expect(doc, contains('FFmpeg'));
    expect(doc, contains('LGPL'));
    expect(doc, contains('Flacora'));
  });

  test('toasts are readable instead of painting transparent text', () {
    final message = File('lib/services/bottom_message.dart').readAsStringSync();
    // scaffoldBackgroundColor is Colors.transparent on Windows and used to be
    // reused as the text colour, which made every toast look empty.
    expect(message, isNot(contains('inactiveBackgroundColor')));
    expect(message, contains('estimateBrightnessForColor'));
    expect(message, contains('SnackBarAction'));
  });

  test('export stages and errors are English', () {
    final queue =
        File('lib/services/export_task_queue.dart').readAsStringSync();
    for (final stage in [
      "'Queued'",
      "'Converting to MP3'",
      "'Done'",
      "'Cancelled'",
      "'Failed'",
    ]) {
      expect(queue, contains(stage), reason: 'missing stage $stage');
    }
    for (final legacy in [
      'In coda',
      'Conversione MP3',
      'Annullata',
      'Brano non disponibile offline',
      'Brano non scaricato',
      'File sorgente mancante',
      'FFmpeg non ha prodotto alcun file',
    ]) {
      expect(queue, isNot(contains(legacy)), reason: 'italian leftover: $legacy');
    }
    final encoder =
        File('lib/services/ffmpeg_audio_encoder.dart').readAsStringSync();
    expect(encoder, isNot(contains('non è riuscito')));
  });

  test('the English catalog is English for the export screen', () {
    final arb = File('lib/l10n/intl_en.arb').readAsStringSync();
    expect(arb, contains('"Open export folder"'));
    expect(arb, contains('"Clear completed"'));
    expect(arb, contains('"Exporting to MP3"'));
    expect(arb, contains('"MP3 saved to your Music folder"'));
    for (final legacy in [
      '"Apri cartella export"',
      '"Pulisci completate"',
      '"Annulla": "Annulla"',
      '"Riprova": "Riprova"',
    ]) {
      expect(arb, isNot(contains(legacy)), reason: 'italian leftover: $legacy');
    }
  });

  test('the download menu reports the real outcome instead of staying silent',
      () {
    final modal = File('lib/utils/bottom_modals.dart').readAsStringSync();
    expect(modal, contains('DownloadFeedback.download'));
    // The song download action used to fire and forget: failures were only
    // written to debugPrint.
    final feedback =
        File('lib/utils/download_feedback.dart').readAsStringSync();
    expect(feedback, contains('DownloadComplete'));
    expect(feedback, contains('DownloadFailed'));
    expect(feedback, contains("'DOWNLOADED'"));
    final arb = File('lib/l10n/intl_en.arb').readAsStringSync();
    expect(arb, contains('"Download complete"'));
    expect(arb, contains('"Download failed"'));
  });
}
