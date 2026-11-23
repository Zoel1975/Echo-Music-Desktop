import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_audio/statistics.dart';

import 'audio_encoder.dart';

/// Pure command builder (unit-testable, no native plugin needed).
List<String> buildMp3Args({
  required String inputPath,
  required String outputPath,
  required int bitrateKbps,
  Map<String, String> tags = const {},
  String? coverUrl,
}) {
  final args = <String>[
    '-nostdin',
    '-y',
    '-i',
    inputPath,
    '-c:a',
    'libmp3lame',
    '-b:a',
    '${bitrateKbps.clamp(64, 320)}k',
    '-map_metadata',
    '0',
    '-id3v2_version',
    '3',
  ];
  if (coverUrl != null && coverUrl.isNotEmpty) {
    args.addAll([
      '-i',
      coverUrl,
      '-map',
      '0:a:0',
      '-map',
      '1:v:0',
      '-c:v',
      'copy',
      '-disposition:v:0',
      'attached_pic',
    ]);
  } else {
    args.addAll(['-vn', '-map', '0:a:0']);
  }
  for (final entry in tags.entries) {
    if (entry.value.trim().isEmpty) continue;
    args.addAll(['-metadata', '${entry.key}=${entry.value}']);
  }
  // The queue writes to `name.mp3.part` and renames it atomically on success.
  // FFmpeg cannot infer the container from `.part`, so force it explicitly.
  args.addAll(['-f', 'mp3']);
  args.add(outputPath);
  return args;
}

/// Real MP3 encoder backed by the LGPL audio-only FFmpeg Kit build.
class FfmpegAudioEncoder implements AudioEncoder {
  /// Reads the source duration (seconds) with FFprobe when the caller has no
  /// metadata. Returns null on failure so encoding can still proceed.
  static Future<int?> _probeDurationMs(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = await session.getMediaInformation();
      final raw = info?.getDuration();
      if (raw == null || raw.isEmpty) return null;
      final seconds = double.tryParse(raw);
      if (seconds == null || seconds <= 0) return null;
      return (seconds * 1000).round();
    } catch (_) {
      return null;
    }
  }

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
    // Local files added with the file picker carry no metadata, so the queue
    // has no duration and the progress bar stayed indeterminate (it never
    // advanced). Probe the source once to get a real ratio.
    final effectiveDurationMs = durationMs ?? await _probeDurationMs(inputPath);
    final done = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      buildMp3Args(
        inputPath: inputPath,
        outputPath: outputPath,
        bitrateKbps: bitrateKbps,
        tags: tags,
        coverUrl: coverUrl,
      )..insertAll(0, const ['-stats_period', '0.2']),
      (s) => done.complete(s),
      null,
      (Statistics statistics) {
        final time = statistics.getTime();
        if (effectiveDurationMs == null || effectiveDurationMs <= 0 || time <= 0) {
          onProgress?.call(null);
          return;
        }
        onProgress
            ?.call((time / effectiveDurationMs).clamp(0.0, 1.0).toDouble());
      },
    );
    final id = session.getSessionId();
    if (id != null) onSession?.call(id);

    final finished = await done.future;
    final code = await finished.getReturnCode();
    if (ReturnCode.isCancel(code)) return; // expected after a user cancel
    if (!ReturnCode.isSuccess(code)) {
      final trace = await finished.getFailStackTrace();
      final allLogs = await finished.getLogsAsString();
      final logLines = allLogs.trim().split('\n');
      final tail = logLines
          .skip(logLines.length > 8 ? logLines.length - 8 : 0)
          .join('\n');
      final detail = (trace?.trim().isNotEmpty == true
              ? trace!.trim()
              : tail.trim().isNotEmpty
                  ? tail
                  : 'FFmpeg non è riuscito a convertire il file');
      throw EncodeException(detail, returnCode: code?.getValue());
    }
    onProgress?.call(1.0);
  }

  @override
  Future<void> cancel(int sessionId) => FFmpegKit.cancel(sessionId);
}
