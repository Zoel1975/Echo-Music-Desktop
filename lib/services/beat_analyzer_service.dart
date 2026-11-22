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

  /// Last tail decode stats, surfaced by the diagnostic probe.
  static int lastTailBytes = 0;
  static String? lastTailError;

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

  static Float64List _pcmFromBytes(Uint8List bytes) {
    final pcm = Float64List(bytes.length ~/ 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < pcm.length; i++) {
      pcm[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return pcm;
  }

  /// Analyze a decoded PCM file directly (useful for tests/local files).
  static BeatAnalysisResult? analyzeBytes(
    Uint8List bytes, {
    Uint8List? tailBytes,
    int? durationMs,
  }) {
    if (bytes.length < sampleRate * 2 * 2) return null;
    return analyzePcm(
      _pcmFromBytes(bytes),
      sampleRate,
      tailMono: tailBytes == null ? null : _pcmFromBytes(tailBytes),
      durationMs: durationMs,
    );
  }

  static Future<BeatAnalysisResult?> analyzePath(
    String key,
    String path, {
    Map<String, String> headers = const {},
    int? durationMs,
  }) async {
    final cached = _cached(key);
    if (cached != null) return cached;

    final dir = await Directory.systemTemp.createTemp('echo_beat_');
    final pcmPath = '${dir.path}${Platform.pathSeparator}beat.pcm';
    try {
      String? headerValue;
      if (headers.isNotEmpty) {
        headerValue = '${headers.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\r\n')}\r\n';
      }
      List<String> decodeArgs(String input, String output,
              {bool fromEnd = false}) =>
          [
            '-nostdin',
            '-y',
            if (fromEnd) '-sseof' else '-t',
            if (fromEnd) '-$windowSeconds' else '$windowSeconds',
            if (headerValue != null) ...['-headers', headerValue],
            '-i',
            input,
            '-vn',
            '-ac',
            '1',
            '-ar',
            '$sampleRate',
            '-f',
            's16le',
            output,
          ];
      final args = decodeArgs(path, pcmPath);
      final session = await FFmpegKit.executeWithArguments(args);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return null;
      final file = File(pcmPath);
      if (!await file.exists()) return null;

      // Tail window for the energy-based mix-out point. `-sseof` seeks from
      // the end, so it also works for long tracks without decoding all of it.
      Uint8List? tailBytes;
      lastTailBytes = 0;
      lastTailError = null;
      try {
        final tailPath = '${dir.path}${Platform.pathSeparator}tail.pcm';
        final tailArgs = decodeArgs(path, tailPath, fromEnd: true);
        final tailSession = await FFmpegKit.executeWithArguments(tailArgs);
        final code = await tailSession.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          final tailFile = File(tailPath);
          if (await tailFile.exists()) {
            tailBytes = await tailFile.readAsBytes();
            lastTailBytes = tailBytes.length;
          }
        } else {
          lastTailError = code?.toString() ?? 'no return code';
        }
      } catch (e) {
        lastTailError = e.toString();
      }

      final result = analyzeBytes(
        await file.readAsBytes(),
        tailBytes: tailBytes,
        durationMs: durationMs,
      );
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

    final rawDuration = song['duration'];
    final durationMs = rawDuration is num
        ? (rawDuration > 10000
            ? rawDuration.toInt()
            : (rawDuration * 1000).toInt())
        : null;
    final path = song['path']?.toString();
    if (path != null && File(path).existsSync()) {
      return analyzePath(id, path, durationMs: durationMs);
    }
    if (!GetIt.I.isRegistered<StreamResolver>()) return null;
    try {
      final stream = await StreamResolver.instance.resolve(id);
      return analyzePath(
        id,
        stream.url,
        headers: stream.headers,
        durationMs: durationMs,
      );
    } catch (_) {
      return null;
    }
  }
}
