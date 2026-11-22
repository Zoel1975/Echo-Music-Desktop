import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'beat_analysis.dart';
import 'stream_resolver.dart';

/// Decodes a short window of a track to mono PCM with FFmpeg Kit and runs the
/// pure [analyzePcm] DSP. Results are cached per video id in Hive so a track is
/// analyzed at most once (phase 1 of the Automix port).
class BeatAnalyzerService {
  BeatAnalyzerService._();

  static const sampleRate = 22050;
  static const windowSeconds = 30;
  static final Map<String, BeatAnalysisResult> _memory = {};

  static const _boxName = 'BEAT_ANALYSIS';

  static BeatAnalysisResult? cached(String key) => _cached(key);

  static BeatAnalysisResult? _cached(String key) {
    final memory = _memory[key];
    if (memory != null) return memory;
    if (!Hive.isBoxOpen(_boxName)) return null;
    final saved = Hive.box(_boxName).get(key);
    if (saved is Map) {
      try {
        return BeatAnalysisResult.fromJson(Map<String, dynamic>.from(saved));
      } catch (_) {}
    }
    return null;
  }

  static void _cache(String key, BeatAnalysisResult result) {
    _memory[key] = result;
    if (Hive.isBoxOpen(_boxName)) {
      Hive.box(_boxName).put(key, result.toJson());
    }
  }

  /// Analyze a decoded PCM file directly (useful for tests/local files).
  static BeatAnalysisResult? analyzeBytes(Uint8List bytes) {
    if (bytes.length < sampleRate * 2 * 2) return null;
    final pcm = Float64List(bytes.length ~/ 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < pcm.length; i++) {
      pcm[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return analyzePcm(pcm, sampleRate);
  }

  static Future<BeatAnalysisResult?> analyzePath(
    String key,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final cached = _cached(key);
    if (cached != null) return cached;

    final dir = await Directory.systemTemp.createTemp('echo_beat_');
    final pcmPath = '${dir.path}${Platform.pathSeparator}beat.pcm';
    try {
      final args = <String>[
        '-nostdin',
        '-y',
        '-t',
        '$windowSeconds',
      ];
      if (headers.isNotEmpty) {
        final header = headers.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\r\n');
        args.addAll(['-headers', '$header\r\n']);
      }
      args.addAll([
        '-i',
        path,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        pcmPath,
      ]);
      final session = await FFmpegKit.executeWithArguments(args);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return null;
      final file = File(pcmPath);
      if (!await file.exists()) return null;
      final result = analyzeBytes(await file.readAsBytes());
      if (result != null) _cache(key, result);
      return result;
    } catch (_) {
      return null;
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Resolves the cached file or the current YouTube stream for [song].
  static Future<BeatAnalysisResult?> analyzeSong(
    Map<String, dynamic> song,
  ) async {
    final id = song['videoId']?.toString() ??
        song['path']?.toString() ??
        '';
    if (id.isEmpty) return null;
    final cached = _cached(id);
    if (cached != null) return cached;

    final path = song['path']?.toString();
    if (path != null && File(path).existsSync()) {
      return analyzePath(id, path);
    }
    if (!GetIt.I.isRegistered<StreamResolver>()) return null;
    try {
      final stream = await StreamResolver.instance.resolve(id);
      return analyzePath(id, stream.url, headers: stream.headers);
    } catch (_) {
      return null;
    }
  }
}
