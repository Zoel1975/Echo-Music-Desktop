import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../generated/l10n.dart';
import '../services/audio_encoder.dart';
import '../services/export_task_queue.dart';

/// User-visible feedback for MP3 export.
///
/// Previously the song menu only showed a toast *after* the whole conversion
/// had finished ("Export started", which was also rendered with an invisible
/// text colour), so there was no way to tell whether anything was happening or
/// where the file went. This shows a live progress bar and ends with the
/// destination file plus a button that opens the export folder.
class ExportFeedback {
  const ExportFeedback._();

  static Future<void> exportSong(
    ScaffoldMessengerState messenger,
    Map<dynamic, dynamic> song,
  ) async {
    final queue = GetIt.I<ExportTaskQueue>();
    final title = song['title']?.toString() ?? '';
    try {
      final task = await queue.enqueueSong(
        Map<String, dynamic>.from(song),
        onTask: (task) => progress(messenger, queue, task, title),
      );
      switch (task.status) {
        case ExportStatus.done:
          done(messenger, task);
        case ExportStatus.failed:
          failed(messenger, task.error ?? task.stage);
        case ExportStatus.queued:
        case ExportStatus.running:
        case ExportStatus.cancelled:
          break;
      }
    } on EncodeException catch (e) {
      failed(messenger, e.message);
    } catch (e) {
      failed(messenger, e.toString());
    }
  }

  /// Live progress while the queue transcodes; stays until the result arrives
  /// or for 30 seconds, whichever comes first.
  static void progress(
    ScaffoldMessengerState messenger,
    ExportTaskQueue queue,
    ExportTask task,
    String title,
  ) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _background(messenger.context),
        content: _ExportProgress(queue: queue, taskId: task.id, title: title),
      ),
    );
  }

  static void done(ScaffoldMessengerState messenger, ExportTask task) {
    messenger.hideCurrentSnackBar();
    final fileName = task.targetPath.split(RegExp(r'[/\\]')).last;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _background(messenger.context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.current.ExportSavedToFolder,
              style: TextStyle(
                color: _foreground(messenger.context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _foreground(messenger.context)),
            ),
            // In-app button instead of SnackBarAction: the action row was not
            // visible on the Windows runner, so users had no way to reach the
            // saved file from the toast.
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => openFolder(task.targetPath),
                  icon: Icon(Icons.folder_open,
                      size: 16, color: _foreground(messenger.context)),
                  label: Text(S.current.OpenFolder),
                  style: TextButton.styleFrom(
                    foregroundColor: _foreground(messenger.context),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void failed(ScaffoldMessengerState messenger, String message) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _background(messenger.context),
        content: Text(
          '${S.current.ExportFailed}: $message',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _foreground(messenger.context)),
        ),
      ),
    );
  }

  static Color _background(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withOpacity(0.95);

  static Color _foreground(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  /// Opens the folder that contains [path] in the system file manager.
  static Future<void> openFolder(String path) async {
    final directory = Directory(path).existsSync()
        ? path
        : (File(path).existsSync() ? File(path).parent.path : path);
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [directory]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [directory]);
      }
    } catch (_) {}
  }
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({
    required this.queue,
    required this.taskId,
    required this.title,
  });

  final ExportTaskQueue queue;
  final String taskId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final matches = queue.tasks.where((t) => t.id == taskId);
        final task = matches.isEmpty ? null : matches.first;
        final progress = task == null || task.status == ExportStatus.queued
            ? null
            : task.progress;
        final percent =
            progress == null ? '' : ' · ${(progress * 100).round()}%';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${S.current.ExportingToMp3} · $title$percent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              color: foreground,
              backgroundColor: foreground.withOpacity(0.25),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => queue.cancel(taskId),
                  child: Text(S.current.Cancel),
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
