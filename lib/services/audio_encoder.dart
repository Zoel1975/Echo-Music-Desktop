/// Encoder abstraction used by the export queue. Tests inject a fake so no
/// native FFmpeg binary is needed to verify the pipeline.
abstract class AudioEncoder {
  /// Converts [inputPath] to an MP3 at [outputPath].
  ///
  /// [durationMs] enables a real progress ratio from FFmpeg's statistics.
  /// [onSession] reports the native session id so the task can be cancelled.
  Future<void> encode({
    required String inputPath,
    required String outputPath,
    required int bitrateKbps,
    int? durationMs,
    Map<String, String> tags = const {},
    void Function(double? progress)? onProgress,
    void Function(int sessionId)? onSession,
  });

  Future<void> cancel(int sessionId);
}

class EncodeException implements Exception {
  const EncodeException(this.message, {this.returnCode});

  final String message;
  final int? returnCode;

  @override
  String toString() => returnCode == null
      ? 'EncodeException: $message'
      : 'EncodeException: $message (exit $returnCode)';
}
