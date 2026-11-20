import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/export_task_queue.dart';
import 'package:Echo/services/playback_cutoff.dart';
import 'package:Echo/screens/coming_soon/coming_soon_catalog.dart';

void main() {
  group('ExportTaskQueue (real export queue)', () {
    test('enqueues, processes and completes a file copy', () async {
      final dir = Directory(
          '${Directory.systemTemp.path}/echo_export_${DateTime.now().microsecondsSinceEpoch}');
      final out = Directory('${dir.path}/out');
      out.createSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final src = File('${dir.path}/song.mp3');
      src.writeAsBytesSync(List<int>.filled(2048, 7));

      final queue = ExportTaskQueue(exportDir: out);
      final task = await queue.enqueue(src.path);
      // Allow the serial drain to finish.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = queue.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.status, ExportStatus.done);
      expect(File(updated.targetPath).existsSync(), isTrue);
      expect(File(updated.targetPath).lengthSync(), 2048);
    });

    test('reports failure for a missing source file', () async {
      final queue = ExportTaskQueue(exportDir: Directory.systemTemp);
      await queue.enqueue('/nonexistent/missing.mp3');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(queue.tasks.first.status, ExportStatus.failed);
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
