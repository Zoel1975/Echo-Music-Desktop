import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import 'audio_encoder.dart';
import 'download_manager.dart';
import 'ffmpeg_audio_encoder.dart';
import 'file_storage.dart';
import 'settings_manager.dart';

enum ExportStatus { queued, running, done, failed, cancelled }

class ExportTask {
  ExportTask({
    required this.id,
    required this.sourcePath,
    required this.targetPath,
    required this.bitrateKbps,
    required this.tags,
    this.coverUrl,
    this.durationMs,
    this.status = ExportStatus.queued,
    this.progress,
    this.error,
    this.stage = 'In coda',
    this.sessionId,
  });

  final String id;
  final String sourcePath;
  final String targetPath;
  final int bitrateKbps;
  final Map<String, String> tags;
  final String? coverUrl;
  final int? durationMs;
  final ExportStatus status;
  final double? progress;
  final String? error;
  final String stage;
  final int? sessionId;

  ExportTask copyWith({
    ExportStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
    String? stage,
    int? sessionId,
  }) =>
      ExportTask(
        id: id,
        sourcePath: sourcePath,
        targetPath: targetPath,
        bitrateKbps: bitrateKbps,
        tags: tags,
        coverUrl: coverUrl,
        durationMs: durationMs,
        status: status ?? this.status,
        progress: progress,
        error: clearError ? null : error,
        stage: stage ?? this.stage,
        sessionId: sessionId ?? this.sessionId,
      );
}

/// Pure filename builder: "Artist - Title.mp3", sanitized for Windows and
/// de-duplicated by the caller. Kept pure for unit tests.
String exportFileNameFor(String sourcePath, Map<String, dynamic>? song) {
  String clean(String? value) => (value ?? '')
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final title = clean(song?['title']?.toString());
  String artist = '';
  final artists = song?['artists'];
  if (artists is List && artists.isNotEmpty && artists.first is Map) {
    artist = clean(artists.first['name']?.toString());
  }
  final base = [artist, title].where((s) => s.isNotEmpty).join(' - ');
  if (base.isNotEmpty) return '$base.mp3';
  final fallback = clean(p.basenameWithoutExtension(sourcePath));
  return '${fallback.isEmpty ? 'audio' : fallback}.mp3';
}

/// Serial export queue: transcodes local audio / downloaded songs to real MP3
/// with an injected [AudioEncoder]. Files are written to a `.part` temp and
/// renamed atomically, so an interrupted conversion never leaves a fake MP3.
class ExportTaskQueue extends ChangeNotifier {
  ExportTaskQueue({Directory? exportDir, AudioEncoder? encoder})
      : _exportDir = exportDir ?? _defaultExportDir(),
        _encoder = encoder ?? FfmpegAudioEncoder();

  final Directory _exportDir;
  final AudioEncoder _encoder;
  final List<ExportTask> _tasks = [];
  final Set<String> _cancelled = <String>{};
  bool _running = false;

  List<ExportTask> get tasks => List.unmodifiable(_tasks);
  Directory get exportDir => _exportDir;

  static Directory _defaultExportDir() {
    try {
      if (GetIt.I.isRegistered<FileStorage>()) {
        return Directory(GetIt.I<FileStorage>().storagePaths.musicPath);
      }
    } catch (_) {}
    return Directory.systemTemp;
  }

  int get _bitrate {
    try {
      if (GetIt.I.isRegistered<SettingsManager>()) {
        return GetIt.I<SettingsManager>().exportBitrateKbps;
      }
    } catch (_) {}
    return 192;
  }

  String exportPath(String fileName) => p.join(_exportDir.path, fileName);

  String _uniqueTarget(String fileName) {
    var file = File(exportPath(fileName));
    var number = 1;
    final ext = p.extension(fileName);
    final stem = p.basenameWithoutExtension(fileName);
    while (file.existsSync()) {
      file = File(exportPath('$stem($number)$ext'));
      number++;
    }
    return file.path;
  }

  Future<ExportTask> enqueue(
    String sourcePath, {
    Map<String, dynamic>? song,
    String? fileName,
  }) async {
    if (!_exportDir.existsSync()) {
      await _exportDir.create(recursive: true);
    }
    final name = fileName ?? exportFileNameFor(sourcePath, song);
    final duration = song?['duration'];
    final durationMs = duration is num
        ? (duration > 10000 ? duration.toInt() : (duration * 1000).toInt())
        : null;
    final task = ExportTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourcePath: sourcePath,
      targetPath: _uniqueTarget(name),
      bitrateKbps: _bitrate,
      durationMs: durationMs,
      tags: {
        'title': song?['title']?.toString() ?? '',
        'artist': song?['artist']?.toString() ??
            (song?['artists'] is List && song!['artists'].isNotEmpty
                ? song['artists'].first['name']?.toString() ?? ''
                : ''),
        'album': song?['album']?['name']?.toString() ?? '',
        'year': song?['year']?.toString() ?? '',
      },
      // Embeds album art in the MP3 like Android's AudioExportService.
      coverUrl: (song?['thumbnails'] is List && song!['thumbnails'].isNotEmpty)
          ? song['thumbnails'].first['url']?.toString()
          : null,
    );
    _tasks.add(task);
    notifyListeners();
    await _drain();
    return _tasks.firstWhere((t) => t.id == task.id);
  }

  /// Exports a downloaded song (offline) by resolving its cached file path.
  Future<ExportTask> enqueueSong(Map<String, dynamic> song) async {
    final videoId = song['videoId']?.toString();
    if (!GetIt.I.isRegistered<DownloadManager>() || videoId == null) {
      throw const EncodeException('Brano non disponibile offline');
    }
    final downloaded = GetIt.I<DownloadManager>().downloads.value
        .whereType<Map>()
        .firstWhere(
          (d) => d['videoId']?.toString() == videoId,
          orElse: () => <String, dynamic>{},
        );
    final path = downloaded['path']?.toString();
    if (path == null || !File(path).existsSync()) {
      throw const EncodeException('Brano non scaricato');
    }
    final meta = Map<String, dynamic>.from(downloaded);
    if (meta['title'] == null) meta['title'] = song['title'];
    if (meta['artists'] == null) meta['artists'] = song['artists'];
    return enqueue(path, song: meta);
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_tasks.any((t) => t.status == ExportStatus.queued)) {
      final i = _tasks.indexWhere((t) => t.status == ExportStatus.queued);
      var task = _tasks[i].copyWith(
        status: ExportStatus.running,
        stage: 'Conversione MP3',
        progress: 0.0,
      );
      _tasks[i] = task;
      notifyListeners();

      final tempPath = '${task.targetPath}.part';
      try {
        final source = File(task.sourcePath);
        if (!source.existsSync()) throw const EncodeException('File sorgente mancante');
        await _encoder.encode(
          inputPath: task.sourcePath,
          outputPath: tempPath,
          bitrateKbps: task.bitrateKbps,
          durationMs: task.durationMs,
          tags: task.tags,
          coverUrl: task.coverUrl,
          onProgress: (progress) {
            if (_cancelled.contains(task.id)) return;
            _tasks[i] = _tasks[i].copyWith(progress: progress);
            notifyListeners();
          },
          onSession: (id) {
            _tasks[i] = _tasks[i].copyWith(sessionId: id);
            notifyListeners();
          },
        );
        if (_cancelled.contains(task.id)) continue;
        final temp = File(tempPath);
        if (!temp.existsSync() || await temp.length() == 0) {
          throw const EncodeException('FFmpeg non ha prodotto alcun file');
        }
        final target = File(task.targetPath);
        if (target.existsSync()) await target.delete();
        await temp.rename(task.targetPath);
        _cancelled.remove(task.id);
        _tasks[i] = _tasks[i].copyWith(
          status: ExportStatus.done,
          stage: 'Completa',
          progress: 1.0,
        );
      } catch (e) {
        final wasCancelled = _cancelled.remove(task.id);
        try {
          final temp = File(tempPath);
          if (temp.existsSync()) await temp.delete();
        } catch (_) {}
        _tasks[i] = _tasks[i].copyWith(
          status: wasCancelled ? ExportStatus.cancelled : ExportStatus.failed,
          stage: wasCancelled ? 'Annullata' : 'Errore',
          error: wasCancelled ? null : e.toString(),
        );
      }
      notifyListeners();
    }
    _running = false;
  }

  Future<void> cancel(String id) async {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0 || _tasks[i].status != ExportStatus.running) return;
    _cancelled.add(id);
    final sessionId = _tasks[i].sessionId;
    if (sessionId != null) {
      try {
        await _encoder.cancel(sessionId);
      } catch (_) {}
    }
    _tasks[i] = _tasks[i].copyWith(
      status: ExportStatus.cancelled,
      stage: 'Annullata',
    );
    notifyListeners();
  }

  void retry(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _cancelled.remove(id);
    _tasks[i] = _tasks[i].copyWith(
      status: ExportStatus.queued,
      stage: 'In coda',
      progress: 0.0,
      error: null,
    );
    notifyListeners();
    unawaited(_drain());
  }

  void clearCompleted() {
    _tasks.removeWhere((t) =>
        t.status == ExportStatus.done ||
        t.status == ExportStatus.failed ||
        t.status == ExportStatus.cancelled);
    notifyListeners();
  }
}
