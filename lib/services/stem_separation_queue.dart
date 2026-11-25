import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart' as ffmpeg;
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart' as ffmpeg;
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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
  StemSeparationQueue._();

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
  bool _allBusy = false;
  String _allStatus = '';
  double _allProgress = 0.0;
  String _provider = 'CPUExecutionProvider';

  List<StemTask> get tasks => List.unmodifiable(_tasks);
  String get provider => _provider;
  bool get setupBusy => _setupBusy;
  String get setupStatus => _setupStatus;
  double get setupProgress => _setupProgress;
  bool get allBusy => _allBusy;
  String get allStatus => _allStatus;
  double get allProgress => _allProgress;

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

  bool cached(String videoId) => File(cachedPath(videoId)).existsSync();

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
      _setAll('Ready — stems separated', 1.0);
    } catch (e) {
      _setAll('Failed: $e', 0.0);
      rethrow;
    } finally {
      _allBusy = false;
      notifyListeners();
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
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final task = _tasks[i];
    Directory dir;
    try {
      dir = await cacheDir.create(recursive: true);
      if (!File(task.sourcePath).existsSync()) {
        throw const StemException('Source file is missing');
      }
      final wav = p.join(dir.path, '${_safe(task.videoId)}.decode.wav');
      await _decode(task.sourcePath, wav);
      await _ensureModel();
      final target = task.outputPath;
      final temp = '$target.part';
      final python = await StemPythonSetup.instance.ensure();
      final requestedProvider = GetIt.I.isRegistered<SettingsManager>()
          ? GetIt.I<SettingsManager>().extra<String>('stemGpu', 'auto')
          : 'auto';
      final process = await Process.start(
        python.executable,
        python.withArgs(
            [helperPath, wav, temp, modelPath, requestedProvider]),
      );
      final progress = RegExp(r'^PROGRESS\s+(\d+)/(\d+)$');
      final providerLine = RegExp(r'^PROVIDER\s+(.+)$');
      var fraction = 0.0;
      final stderr = StringBuffer();
      final stdoutDone = process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((chunk) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          final providerMatch = providerLine.firstMatch(trimmed);
          if (providerMatch != null) {
            _provider = providerMatch.group(1)!.trim();
            continue;
          }
          final match = progress.firstMatch(trimmed);
          if (match != null) {
            final current = int.tryParse(match.group(1) ?? '') ?? 0;
            final total = int.tryParse(match.group(2) ?? '') ?? 1;
            fraction = (current / total).clamp(0.0, 1.0);
            _update(i, progress: 0.2 + fraction * 0.8);
          }
        }
      });
      await process.stderr
          .transform(const SystemEncoding().decoder)
          .forEach(stderr.write);
      await stdoutDone.asFuture<void>();
      final code = await process.exitCode;
      if (code != 0 || !File(temp).existsSync()) {
        final detail = stderr.toString().trim().isEmpty
            ? 'separator exited with code $code'
            : stderr.toString().trim().split('\n').last;
        debugPrint('[stems] helper stderr: ${stderr.toString()}');
        throw StemException(detail);
      }
      final targetFile = File(target);
      if (targetFile.existsSync()) await targetFile.delete();
      await File(temp).rename(target);
      try {
        await File(wav).delete();
      } catch (_) {}
      _update(i, status: StemTaskStatus.done, progress: 1.0);
      StemMixerService.instance.setStemFile(target, task.videoId);
    } catch (e) {
      _update(i,
          status: StemTaskStatus.failed,
          error: e is StemException ? e.message : e.toString());
    }
  }

  void _update(int i, {StemTaskStatus? status, double? progress, String? error}) {
    if (i < 0 || i >= _tasks.length) return;
    _tasks[i] = _tasks[i].copyWith(status: status, progress: progress, error: error);
    if (_allBusy && progress != null) {
      _allProgress = 0.5 + progress * 0.5;
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
