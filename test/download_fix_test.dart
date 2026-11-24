import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloads use the same stream resolver as playback', () {
    final manager =
        File('lib/services/download_manager.dart').readAsStringSync();
    expect(manager, contains('StreamResolver.instance.resolve'));
    expect(manager, contains('DownloadStreamInfo'));
    expect(manager, contains('lastDownloadError'));
    // The old code only resolved through youtube_explode's androidVr client;
    // songs that played fine could still fail to download.
    expect(manager, contains('ytExplode.videos.streamsClient.getManifest'));
    // Low bitrate must really pick the lowest stream.
    expect(manager, contains("quality == 'low' ? streamInfos.first : streamInfos.last"));

    final client = File('lib/services/stream_client.dart').readAsStringSync();
    expect(client, contains('class DownloadStreamInfo'));
    expect(client, isNot(contains('    StreamInfo streamInfo,')));
  });

  test('the UI reports the real download error', () {
    final feedback =
        File('lib/utils/download_feedback.dart').readAsStringSync();
    expect(feedback, contains('lastDownloadError'));
    expect(feedback, contains('DownloadComplete'));
    expect(feedback, contains('DownloadFailed'));
  });
}
