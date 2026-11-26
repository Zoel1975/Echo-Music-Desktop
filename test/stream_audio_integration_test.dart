import 'dart:io';

import 'package:Echo/services/yt_audio_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = Platform.environment['LIVE_STREAM'] == '1';

  test(
    'YouTubeAudioSource serves a real ranged audio chunk',
    skip: !live,
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final source = YouTubeAudioSource(videoId: 'dQw4w9WgXcQ', quality: 'high');
      final response = await source.request(0, 1023);
      expect(response.offset, 0);
      expect(response.contentLength, 1024);
      expect(response.sourceLength, greaterThan(1024));
      expect(response.contentType, contains('audio/'));
      final bytes = await response.stream.first;
      expect(bytes.length, greaterThan(0));
    },
  );
}
