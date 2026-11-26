import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart' as ffmpeg;
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart' as ffmpeg;
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/app_messenger.dart';

import 'bottom_message.dart';
import 'download_manager.dart';
import 'file_storage.dart';
import 'settings_manager.dart';
import 'stem_mixer_service.dart';
import 'stem_python_setup.dart';

enum StemTaskStatus { queued, running, done, failed }

class StemTask {
  const StemTask({
    required this.id,
    required this.videoId,
    required this.sourcePath,
    required this.outputPath,
    this.status = StemTaskStatus.queued,
    this.progress = 0.0,
    this.error,
  });

  final String id;
  final String videoId;
  final String sourcePath;
  final String outputPath;
  final StemTaskStatus status;
  final double progress;
  final String? error;

  StemTask copyWith({
    StemTaskStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
  }) =>
      StemTask(
        id: id,
        videoId: videoId,
        sourcePath: sourcePath,
        outputPath: outputPath,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: clearError ? null : error,
      );
}

/// Background queue that produces four-channel stem files.
///
/// The model is downloaded once and cached next to the stems. The Python
/// helper only needs numpy, onnxruntime and soundfile; decoding to 44.1 kHz
/// stereo WAV is done with the FFmpeg build already bundled in the app.
class StemSeparationQueue extends ChangeNotifier {
  StemSeparationQueue._() {
    _cleanupStaleTemps();
  }

  /// Failed or interrupted runs leave `.part` and `.decode.wav` files behind.
  /// They can reach hundreds of megabytes each and were the main source of
  /// startup slowdowns after a crash. Only files older than 12 hours are
  /// removed, so a separation running in another process is never touched.
  void _cleanupStaleTemps() {
    try {
      final dir = cacheDir;
      if (!dir.existsSync()) return;
      final cutoff = DateTime.now().subtract(const Duration(hours: 12));
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.path;
        if (!name.endsWith('.part') && !name.endsWith('.decode.wav')) continue;
        if (entity.statSync().modified.isAfter(cutoff)) continue;
        entity.deleteSync();
        debugPrint('[stems] removed stale temp: ${entity.path}');
      }
    } catch (e) {
      debugPrint('[stems] temp cleanup skipped: $e');
    }
  }

  static final StemSeparationQueue instance = StemSeparationQueue._();

  static const String modelUrl =
      'https://huggingface.co/StemSplitio/htdemucs-onnx/resolve/main/'
      'htdemucs_fp16weights.onnx?download=true';
  static const int expectedModelBytes = 166 * 1024 * 1024;

  final List<StemTask> _tasks = [];
  bool _running = false;
  bool _prepared = false;
  bool _setupBusy = false;
  String _setupStatus = '';
  double _setupProgress = 0.0;
  bool _playlistBusy = false;
  int _playlistDone = 0;
  int _playlistTotal = 0;
  final List<String> _playlistErrors = [];
  int _playlistSeparated = 0;
  int _playlistSkipped = 0;
  bool _allBusy = false;
  String _allStatus = '';
  double _allProgress = 0.0;
  String _provider = 'CPUExecutionProvider';
  String _stage = '';
  int _chunkCurrent = 0;
  int _chunkTotal = 0;
  DateTime? _runStart;

  List<StemTask> get tasks => List.unmodifiable(_tasks);
  String get provider => _provider;
  String get stage => _stage;
  int get chunkCurrent => _chunkCurrent;
  int get chunkTotal => _chunkTotal;
  int get elapsedSeconds => _runStart == null
      ? 0
      : DateTime.now().difference(_runStart!).inSeconds;
  bool get setupBusy => _setupBusy;
  String get setupStatus => _setupStatus;
  double get setupProgress => _setupProgress;
  bool get playlistBusy => _playlistBusy;
  int get playlistDone => _playlistDone;
  int get playlistTotal => _playlistTotal;
  List<String> get playlistErrors => List.unmodifiable(_playlistErrors);
  int get playlistSeparated => _playlistSeparated;
  int get playlistSkipped => _playlistSkipped;
  double get playlistProgress =>
      _playlistTotal == 0 ? 0 : _playlistDone / _playlistTotal;
  bool get allBusy => _allBusy;
  String get allStatus => _allStatus;
  double get allProgress => _allProgress;

  /// Global feedback that survives leaving the playlist page: the batch can
  /// run for hours, so the user must be able to see that it is alive.
  void _notify(String text) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    BottomMessage.showOn(messenger, text,
        duration: const Duration(seconds: 5));
  }

  void _setAll(String status, double progress) {
    _allStatus = status;
    _allProgress = progress;
    notifyListeners();
  }

  void _setSetup(String status, double progress) {
    _setupStatus = status;
    _setupProgress = progress;
    if (_allBusy) _allProgress = 0.15 + progress * 0.3;
    notifyListeners();
  }

  Directory get cacheDir {
    try {
      if (GetIt.I.isRegistered<FileStorage>()) {
        return Directory(p.join(GetIt.I<FileStorage>().storagePaths.musicPath,
            'Stems'));
      }
    } catch (_) {}
    return Directory(p.join(Directory.systemTemp.path, 'echo_stems'));
  }

  String get modelPath =>
      p.join(cacheDir.path, 'models', 'htdemucs_fp16weights.onnx');
  String get helperPath => p.join(File(Platform.resolvedExecutable).parent.path,
      'tools', 'stems', 'separate.py');

  String cachedPath(String videoId) =>
      p.join(cacheDir.path, '${_safe(videoId)}.stems.wav');

  List<String> stemPaths(String videoId) {
    final base = cachedPath(videoId).replaceFirst(RegExp(r'\.stems\.wav$'), '');
    return List<String>.generate(4, (i) => '$base.${stemNames[i].toLowerCase()}.wav');
  }

  static String _safe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  String get pythonExecutable {
    try {
      if (GetIt.I.isRegistered<SettingsManager>()) {
        final configured = GetIt.I<SettingsManager>()
            .extra<String>('stemPython', '')
            .trim();
        if (configured.isNotEmpty) return configured;
      }
    } catch (_) {}
    return Platform.environment['ECHO_PYTHON'] ?? 'python';
  }

  /// A track is usable only when both the four-channel cache and all four
  /// mono stems exist. A partial run can leave mono files behind, while older
  /// caches can have only the four-channel file; neither can be mixed.
  bool cached(String videoId) =>
      File(cachedPath(videoId)).existsSync() &&
      stemPaths(videoId).every((path) => File(path).existsSync());

  void clearCompleted() {
    _tasks.removeWhere((t) =>
        t.status == StemTaskStatus.done || t.status == StemTaskStatus.failed);
    notifyListeners();
  }

  /// One-shot setup: find/install Python and download the ONNX model.
  /// Called automatically by [enqueue]; the UI only shows progress.
  Future<void> prepare() async {
    if (_prepared) return;
    if (_setupBusy) {
      while (_setupBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    _setupBusy = true;
    try {
      _setSetup('Checking Python…', 0.0);
      await StemPythonSetup.instance.ensure();
      _setSetup('Downloading the separation model (166 MB)…', 0.05);
      await _ensureModel(onProgress: (value) {
        _setSetup('Downloading the separation model (166 MB)…',
            0.05 + value * 0.9);
      });
      _setSetup('Ready', 1.0);
      _prepared = true;
    } finally {
      _setupBusy = false;
      notifyListeners();
    }
  }

  /// One button: download the song if needed, set up Python, download the
  /// model and separate. Progress is exposed through [allStatus]/[allProgress].
  Future<void> startAll(Map<String, dynamic> song, String videoId) async {
    if (_allBusy) return;
    _allBusy = true;
    try {
      var path = song['path']?.toString();
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        _setAll('Downloading track…', 0.02);
        await GetIt.I<DownloadManager>().downloadSong(song);
        for (final d in GetIt.I<DownloadManager>().downloads.value) {
          if (d['videoId']?.toString() == videoId && d['path'] != null) {
            path = d['path'].toString();
            break;
          }
        }
      }
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        throw 'Could not get the audio file';
      }
      _setAll('Preparing Python and model…', 0.15);
      await prepare();
      _setAll('Separating…', 0.5);
      await enqueue(videoId, path);
      _setAll('Done — stems ready to mix', 1.0);
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (_allBusy) return;
        clearCompleted();
        _setAll('', 0.0);
      });
    } catch (e) {
      _setAll('Failed: $e', 0.0);
      rethrow;
    } finally {
      _allBusy = false;
      notifyListeners();
    }
  }

  Future<String?> _downloadedPath(String videoId) async {
    try {
      for (final download in GetIt.I<DownloadManager>().downloads.value) {
        if (download['videoId']?.toString() != videoId) continue;
        final path = download['path']?.toString();
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Queue every track of a playlist. Missing files are downloaded first;
  /// a failed track does not stop the rest. Every failure is recorded so the
  /// button can explain what happened instead of silently doing nothing.
  Future<void> enqueuePlaylist(List<Map<String, dynamic>> songs) async {
    if (_playlistBusy) return;
    _playlistBusy = true;
    _playlistTotal = songs.length;
    _playlistDone = 0;
    _playlistSeparated = 0;
    _playlistSkipped = 0;
    _playlistErrors.clear();
    notifyListeners();
    _notify('Stem separation started for $songs.length songs (runs in background)');
    try {
      await prepare();
      final downloads = GetIt.I<DownloadManager>();
      for (var index = 0; index < songs.length; index++) {
        final song = songs[index];
        // Start the next few downloads while the current track is being
        // separated. Inference stays sequential, but the network no longer
        // adds a full round trip to every track of a long playlist.
        for (var ahead = index + 1;
            ahead <= index + 3 && ahead < songs.length;
            ahead++) {
          final nextId = songs[ahead]['videoId']?.toString() ?? '';
          if (nextId.isEmpty || cached(nextId)) continue;
          unawaited(downloads.downloadSong(songs[ahead]).catchError((Object e) {
            debugPrint('stem playlist prefetch: $nextId failed: $e');
          }));
        }
        final id = song['videoId']?.toString() ?? '';
        if (id.isEmpty) {
          _playlistErrors.add('Brano senza identificativo');
          _playlistDone++;
          notifyListeners();
          continue;
        }
        if (cached(id)) {
          _playlistSkipped++;
          _playlistDone++;
          notifyListeners();
          continue;
        }
        try {
          var path = song['path']?.toString();
          if (path == null || path.isEmpty || !File(path).existsSync()) {
            path = await _downloadedPath(id);
          }
          if (path == null) {
            await downloads.downloadSong(song);
            // A download can be queued behind other downloads, so the path is
            // not necessarily available when downloadSong returns.
            for (var attempt = 0; attempt < 150 && path == null; attempt++) {
              path = await _downloadedPath(id);
              if (path == null) {
                await Future<void>.delayed(const Duration(milliseconds: 200));
              }
            }
            if (path == null) {
              final reason = downloads.lastDownloadError;
              throw reason == null
                  ? 'download non riuscito'
                  : 'download non riuscito: $reason';
            }
          }
          if (!File(path).existsSync()) throw 'file audio mancante: $path';
          final task = await enqueue(id, path);
          if (task.status == StemTaskStatus.failed) {
            _playlistErrors.add('$id: ${task.error ?? 'separazione fallita'}');
          } else {
            _playlistSeparated++;
          }
        } catch (e) {
          debugPrint('stem playlist: $id failed: $e');
          _playlistErrors.add('$id: $e');
        }
        _playlistDone++;
        notifyListeners();
      }
    } finally {
      _playlistBusy = false;
      notifyListeners();
      _notify(_playlistErrors.isEmpty
          ? 'Stem batch finished: $_playlistSeparated separated, '
              '$_playlistSkipped already ready'
          : 'Stem batch finished: $_playlistSeparated separated, '
              '${_playlistErrors.length} failed — ${_playlistErrors.first}');
    }
  }

  Future<StemTask> enqueue(String videoId, String sourcePath) async {
    await prepare();
    final existing = _tasks.indexWhere((t) =>
        t.videoId == videoId && t.status == StemTaskStatus.queued);
    if (existing >= 0) return _tasks[existing];
    final task = StemTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      videoId: videoId,
      sourcePath: sourcePath,
      outputPath: cachedPath(videoId),
    );
    _tasks.add(task);
    notifyListeners();
    await _drain();
    return _tasks.firstWhere((t) => t.id == task.id);
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_tasks.any((t) => t.status == StemTaskStatus.queued)) {
      final i = _tasks.indexWhere((t) => t.status == StemTaskStatus.queued);
      _tasks[i] = _tasks[i].copyWith(status: StemTaskStatus.running,
          progress: 0.0, clearError: true);
      notifyListeners();
      await _run(_tasks[i].id);
      notifyListeners();
    }
    _running = false;
  }

  Future<void> _run(String id) async {
    final startIndex = _tasks.indexWhere((t) => t.id == id);
    if (startIndex < 0) return;
    final task = _tasks[startIndex];
    void update({
      StemTaskStatus? status,
      double? progress,
      String? error,
    }) {
      // Never keep a captured index: tasks can be added or cleared while the
      // helper process runs, which would update the wrong task.
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index >= 0) _update(index, status: status, progress: progress, error: error);
    }

    void stage(String value) {
      _stage = value;
      debugPrint('[stems] $id stage: $value');
      notifyListeners();
    }

    Directory dir;
    String? pendingWav;
    String? pendingPart;
    _chunkCurrent = 0;
    _chunkTotal = 0;
    _runStart = null;
    try {
      stage('decoding');
      dir = await cacheDir.create(recursive: true);
      if (!File(task.sourcePath).existsSync()) {
        throw const StemException('Source file is missing');
      }
      final wav = p.join(dir.path, '${_safe(task.videoId)}.decode.wav');
      pendingWav = wav;
      await _decode(task.sourcePath, wav);
      stage('model');
      await _ensureModel();
      stage('starting helper');
      final target = task.outputPath;
      final temp = '$target.part';
      pendingPart = temp;
      final python = await StemPythonSetup.instance.ensure();
      final requestedProvider = GetIt.I.isRegistered<SettingsManager>()
          ? GetIt.I<SettingsManager>().extra<String>('stemGpu', 'auto')
          : 'auto';
      final fast = GetIt.I.isRegistered<SettingsManager>() &&
          GetIt.I<SettingsManager>().extra<bool>('stemFast', true);
      final process = await Process.start(
        python.executable,
        python.withArgs([
          helperPath, wav, temp, modelPath, requestedProvider,
          fast ? '0.1' : '0.25',
        ]),
      );
      final progress = RegExp(r'^PROGRESS\s+(\d+)/(\d+)$');
      final providerLine = RegExp(r'^PROVIDER\s+(.+)$');
      var fraction = 0.0;
      final stderr = StringBuffer();
      // Drain both streams with forEach: StreamSubscription.asFuture() can
      // remain pending after the child exits, which left the task stuck at
      // 100% with the output file already written.
      final stdoutDone = process.stdout
          .transform(const SystemEncoding().decoder)
          .forEach((chunk) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          final providerMatch = providerLine.firstMatch(trimmed);
          if (providerMatch != null) {
            _provider = providerMatch.group(1)!.trim();
            continue;
          }
          final match = progress.firstMatch(trimmed);
          if (match != null) {
            _chunkCurrent = int.tryParse(match.group(1) ?? '') ?? 0;
            _chunkTotal = int.tryParse(match.group(2) ?? '') ?? 1;
            _runStart ??= DateTime.now();
            final current = _chunkCurrent;
            final total = _chunkTotal;
            fraction = (current / total).clamp(0.0, 1.0);
            update(progress: 0.2 + fraction * 0.8);
          }
        }
      });
      final stderrDone = process.stderr
          .transform(const SystemEncoding().decoder)
          .forEach(stderr.write);
      stage('waiting for helper streams');
      await Future.wait<void>([stdoutDone, stderrDone]);
      stage('helper exited');
      final code = await process.exitCode;
      stage('return code $code');
      if (code != 0 || !File(temp).existsSync()) {
        final detail = stderr.toString().trim().isEmpty
            ? 'separator exited with code $code'
            : stderr.toString().trim().split('\n').last;
        debugPrint('[stems] helper stderr: ${stderr.toString()}');
        throw StemException(detail);
      }
      stage('writing output');
      final targetFile = File(target);
      if (targetFile.existsSync()) await targetFile.delete();
      await File(temp).rename(target);
      try {
        await File(wav).delete();
      } catch (_) {}
      stage('done');
      update(status: StemTaskStatus.done, progress: 1.0);
      // Only the track that is actually playing may take over the mixer. A
      // playlist batch finishes tracks in the background while the user keeps
      // listening to another song.
      unawaited(StemMixerService.instance
          .activateIfCurrent(task.videoId, stemPaths(task.videoId)));
    } catch (e) {
      // Remove this run's temporary files immediately instead of leaving
      // hundreds of megabytes behind until the next startup.
      for (final path in [pendingPart, pendingWav]) {
        if (path == null) continue;
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      stage('failed: $e');
      update(
          status: StemTaskStatus.failed,
          error: e is StemException ? e.message : e.toString());
    }
  }

  void _update(int i, {StemTaskStatus? status, double? progress, String? error}) {
    if (i < 0 || i >= _tasks.length) return;
    _tasks[i] = _tasks[i].copyWith(status: status, progress: progress, error: error);
    if (_allBusy && progress != null) {
      // Never show a full bar while the helper is still writing the file.
      _allProgress = 0.5 + progress.clamp(0.0, 1.0) * 0.48;
    }
    notifyListeners();
  }

  Future<void> _decode(String input, String output) async {
    if (File(output).existsSync()) await File(output).delete();
    final done = Completer<dynamic>();
    await ffmpeg.FFmpegKit.executeWithArgumentsAsync(
      [
        '-nostdin', '-y', '-i', input, '-vn', '-ac', '2', '-ar', '44100',
        '-c:a', 'pcm_f32le', '-f', 'wav', output,
      ],
      (session) => done.complete(session),
      null,
      null,
    );
    final session = await done.future;
    final code = await session.getReturnCode();
    if (!ffmpeg.ReturnCode.isSuccess(code)) {
      throw StemException('Could not decode the source to 44.1 kHz stereo');
    }
  }

  Future<void> _ensureModel({void Function(double)? onProgress}) async {
    final file = File(modelPath);
    if (file.existsSync() && file.lengthSync() > expectedModelBytes ~/ 2) {
      return;
    }
    await file.parent.create(recursive: true);
    final request = http.Request('GET', Uri.parse(modelUrl));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw StemException('Model download failed (HTTP ${response.statusCode})');
    }
    final total = response.contentLength ?? expectedModelBytes;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      final fraction = (received / total).clamp(0.0, 1.0);
      onProgress?.call(fraction);
      final i = _tasks.indexWhere((t) => t.status == StemTaskStatus.running);
      _update(i, progress: fraction * 0.2);
    }
    await sink.close();
  }
}

class StemException implements Exception {
  const StemException(this.message);
  final String message;
  @override
  String toString() => 'StemException: $message';
}
