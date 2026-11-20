import 'dart:io';

import 'package:flutter/foundation.dart';

/// Desktop port of Android `StorageSettings.kt`: reports and clears the app's
/// on-disk caches (downloaded song cache and artwork/thumbnail cache).
class StorageService {
  StorageService({Directory? tempDir})
      : _tempDir = tempDir ?? Directory.systemTemp;

  final Directory _tempDir;

  Directory get songCacheDir => Directory('${_tempDir.path}/echo_song_cache');
  Directory get imageCacheDir => Directory('${_tempDir.path}/echo_image_cache');

  int _sizeOf(Directory dir) {
    if (!dir.existsSync()) return 0;
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
  }

  int get songCacheBytes => _sizeOf(songCacheDir);
  int get imageCacheBytes => _sizeOf(imageCacheDir);

  Future<int> clearSongCache() => _clear(songCacheDir);
  Future<int> clearImageCache() => _clear(imageCacheDir);

  Future<int> _clear(Directory dir) async {
    if (!dir.existsSync()) return 0;
    final bytes = _sizeOf(dir);
    try {
      dir.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('[storage] failed to clear ${dir.path}: $e');
      return 0;
    }
    return bytes;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
