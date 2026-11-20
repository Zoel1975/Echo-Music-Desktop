import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum ExportStatus { queued, running, done, failed }

class ExportTask {
  ExportTask({
    required this.id,
    required this.sourcePath,
    required this.targetPath,
    this.status = ExportStatus.queued,
    this.progress = 0.0,
    this.error,
  });

  final String id;
  final String sourcePath;
  final String targetPath;
  final ExportStatus status;
  final double progress;
  final String? error;

  ExportTask copyWith({
    ExportStatus? status,
    double? progress,
    String? error,
  }) =>
      ExportTask(
        id: id,
        sourcePath: sourcePath,
        targetPath: targetPath,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

/// Real port of Android `AudioExportService` + `ExportTaskQueue`: a serial
/// background queue that copies local audio files to the user's export folder
/// and reports progress. Pure/IO-based, no Android dependencies.
class ExportTaskQueue extends ChangeNotifier {
  ExportTaskQueue({Directory? exportDir})
      : _exportDir = exportDir ?? Directory.systemTemp;

  final Directory _exportDir;
  final List<ExportTask> _tasks = [];
  bool _running = false;

  List<ExportTask> get tasks => List.unmodifiable(_tasks);

  String exportPath(String fileName) =>
      '${_exportDir.path}${Platform.pathSeparator}$fileName';

  Future<ExportTask> enqueue(String sourcePath, {String? fileName}) async {
    final name = fileName ??
        sourcePath.split(RegExp(r'[/\\]')).last;
    final task = ExportTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourcePath: sourcePath,
      targetPath: exportPath(name),
    );
    _tasks.add(task);
    notifyListeners();
    await _drain();
    return task;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_tasks.any((t) => t.status == ExportStatus.queued)) {
      final i = _tasks.indexWhere((t) => t.status == ExportStatus.queued);
      final task = _tasks[i];
      _tasks[i] = task.copyWith(status: ExportStatus.running, progress: 0.1);
      notifyListeners();
      try {
        final source = File(task.sourcePath);
        if (!source.existsSync()) throw Exception('Source file missing');
        final target = File(task.targetPath);
        await source.copy(task.targetPath);
        final size = await target.length();
        _tasks[i] = _tasks[i].copyWith(
          status: ExportStatus.done,
          progress: size > 0 ? 1.0 : 0.99,
        );
      } catch (e) {
        _tasks[i] = _tasks[i].copyWith(
          status: ExportStatus.failed,
          error: e.toString(),
        );
      }
      notifyListeners();
    }
    _running = false;
  }

  void clearCompleted() {
    _tasks.removeWhere((t) =>
        t.status == ExportStatus.done || t.status == ExportStatus.failed);
    notifyListeners();
  }
}
