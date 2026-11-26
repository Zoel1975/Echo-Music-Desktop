import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/file_storage.dart';

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

  test('download file names are Windows-safe and errors are surfaced', () {
    final name = FileStorage.safeMusicFileName({
      'title': '  Signorina:Ciao? (con Drast*)/|"  ',
      'videoId': 'VQi37P2N_WA',
    });
    expect(name, isNot(contains(':')));
    expect(name, isNot(contains('?')));
    expect(name, isNot(contains('*')));
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('\\')));
    expect(name, isNot(contains('|')));
    expect(name, isNot(contains('"')));
    expect(name.trim(), name);
    expect(FileStorage.safeMusicFileName({'title': 'CON'}), '_CON');
    expect(FileStorage.safeMusicFileName({'title': ''}) != '', isTrue);

    final storage =
        File('lib/services/file_storage.dart').readAsStringSync();
    expect(storage, contains('static String safeMusicFileName('));
    expect(storage, contains('rethrow;'));
    expect(storage, isNot(contains('      await file.writeAsBytes(data, flush: true);\n\n      await file.writeAsBytes')));
  });
}
