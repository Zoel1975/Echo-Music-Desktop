import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/audio_encoder.dart';
import 'package:Echo/services/export_task_queue.dart';
import 'package:Echo/services/playback_cutoff.dart';
import 'package:Echo/screens/coming_soon/coming_soon_catalog.dart';

class FakeAudioEncoder implements AudioEncoder {
  int calls = 0;
  String? lastInput;
  String? lastOutput;
  int? cancelledSession;
  bool pauseBeforeFinish = false;
  Completer<void>? _pause;

  @override
  Future<void> encode({
    required String inputPath,
    required String outputPath,
    required int bitrateKbps,
    int? durationMs,
    Map<String, String> tags = const {},
    String? coverUrl,
    void Function(double? progress)? onProgress,
    void Function(int sessionId)? onSession,
  }) async {
    calls++;
    lastInput = inputPath;
    lastOutput = outputPath;
    onSession?.call(42);
    onProgress?.call(0.5);
    if (pauseBeforeFinish) {
      _pause = Completer<void>();
      await _pause!.future;
    }
    File(outputPath).writeAsBytesSync(const [0x49, 0x44, 0x33]);
    onProgress?.call(1.0);
  }

  void allowFinish() {
    if (_pause != null && !_pause!.isCompleted) _pause!.complete();
  }

  @override
  Future<void> cancel(int sessionId) async {
    cancelledSession = sessionId;
    allowFinish();
  }
}

void main() {
  group('ExportTaskQueue (real MP3 transcoding)', () {
    late Directory dir;
    late Directory out;
    late FakeAudioEncoder encoder;

    setUp(() {
      dir = Directory(
          '${Directory.systemTemp.path}/echo_export_${DateTime.now().microsecondsSinceEpoch}');
      out = Directory('${dir.path}/out')..createSync(recursive: true);
      encoder = FakeAudioEncoder();
    });
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('transcodes via the encoder and writes an atomic .mp3', () async {
      final src = File('${dir.path}/song.m4a')..writeAsBytesSync([1, 2, 3]);
      final queue = ExportTaskQueue(exportDir: out, encoder: encoder);
      final task = await queue.enqueue(src.path);

      final updated = queue.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.status, ExportStatus.done);
      expect(updated.progress, 1.0);
      expect(updated.targetPath, endsWith('.mp3'));
      expect(File(updated.targetPath).existsSync(), isTrue);
      expect(encoder.calls, 1);
      expect(encoder.lastInput, src.path);
      expect(encoder.lastOutput, endsWith('.mp3.part'));
      expect(File('${updated.targetPath}.part').existsSync(), isFalse);
    });

    test('uses Artist - Title naming and sanitizes Windows characters', () {
      final name = exportFileNameFor('/tmp/a.m4a', {
        'title': 'Bad: name?/song',
        'artists': [
          {'name': 'Some/Artist'}
        ],
      });
      expect(name, 'SomeArtist - Bad namesong.mp3');
    });

    test('reports failure for a missing source file without encoding', () async {
      final queue = ExportTaskQueue(exportDir: out, encoder: encoder);
      await queue.enqueue('/nonexistent/missing.mp3');
      expect(queue.tasks.first.status, ExportStatus.failed);
      expect(encoder.calls, 0);
    });

    test('cancel stops an active task and retry re-encodes it', () async {
      final src = File('${dir.path}/song.m4a')..writeAsBytesSync([1, 2, 3]);
      encoder.pauseBeforeFinish = true;
      final queue = ExportTaskQueue(exportDir: out, encoder: encoder);
      final future = queue.enqueue(src.path);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final id = queue.tasks.first.id;
      await queue.cancel(id);
      encoder.allowFinish();
      await future;
      expect(queue.tasks.first.status, ExportStatus.cancelled);
      expect(encoder.cancelledSession, isNotNull);

      encoder.pauseBeforeFinish = false;
      queue.retry(id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(queue.tasks.first.status, ExportStatus.done);
      expect(encoder.calls, 2);
    });
  });

  group('PlaybackCutoffGuard / AdaptivePreArmManager', () {
    test('pre-arms near the end of a track', () {
      expect(
        PlaybackCutoffGuard.shouldPreArm(
          positionMs: 55000,
          durationMs: 60000,
          bufferedMs: 60000,
          baseLeadMs: 5000,
        ),
        isTrue,
      );
      expect(
        PlaybackCutoffGuard.shouldPreArm(
          positionMs: 10000,
          durationMs: 60000,
          bufferedMs: 60000,
          baseLeadMs: 5000,
        ),
        isFalse,
      );
    });

    test('arms earlier when buffering is thin', () {
      // remaining 6s > base lead 5s, but buffered ahead is only 2s →
      // adaptive lead becomes 7.5s, so it should arm.
      expect(
        PlaybackCutoffGuard.shouldPreArm(
          positionMs: 54000,
          durationMs: 60000,
          bufferedMs: 56000,
          baseLeadMs: 5000,
        ),
        isTrue,
      );
    });
  });

  test('converted features no longer have placeholder routes', () {
    for (final route in ['podcasts', 'music_flow_full', 'canvas_ambient', 'export_queue']) {
      expect(
        ComingSoonCatalog.features.any((f) => f.route == route),
        isFalse,
        reason: '$route should be a real screen, not a placeholder',
      );
    }
  });
}
