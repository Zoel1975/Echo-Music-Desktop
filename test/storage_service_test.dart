import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/storage_service.dart';

void main() {
  test('storage service reports and clears real cache files', () async {
    final dir = Directory(
        '${Directory.systemTemp.path}/echo_storage_test_${DateTime.now().microsecondsSinceEpoch}');
    dir.createSync(recursive: true);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final service = StorageService(tempDir: dir);
    // Create fake cached files.
    service.songCacheDir.createSync(recursive: true);
    File('${service.songCacheDir.path}/a.mp4').writeAsBytesSync(List.filled(2048, 1));
    expect(service.songCacheBytes, 2048);

    final cleared = await service.clearSongCache();
    expect(cleared, 2048);
    expect(service.songCacheBytes, 0);
    expect(service.songCacheDir.existsSync(), isFalse);
  });

  test('formatBytes produces human-readable sizes', () {
    expect(StorageService.formatBytes(512), '512 B');
    expect(StorageService.formatBytes(2048), contains('KB'));
    expect(StorageService.formatBytes(2 * 1024 * 1024), contains('MB'));
  });
}
