import 'dart:io';

import 'package:flutter/foundation.dart';

/// Android `LocalSongScanner` port: scans folders for audio files and builds
/// song maps compatible with MediaPlayer's local-file path (`status: LOCAL`,
/// `path` set). Metadata is derived from the file name when no tag reader is
/// available (no native tag plugin on desktop).
class LocalSongScanner {
  LocalSongScanner({this.extensions = const [
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
  ]});

  final List<String> extensions;

  bool isAudioFile(String path) {
    final lower = path.toLowerCase();
    return extensions.any(lower.endsWith);
  }

  /// Parse "Artist - Title.ext" into artist + title; otherwise file stem.
  ({String title, String artist}) parseName(String fileName) {
    var stem = fileName;
    final dot = stem.lastIndexOf('.');
    if (dot > 0) stem = stem.substring(0, dot);
    final dash = stem.indexOf(' - ');
    if (dash > 0) {
      return (
        title: stem.substring(dash + 3).trim(),
        artist: stem.substring(0, dash).trim(),
      );
    }
    return (title: stem.trim(), artist: 'Unknown artist');
  }

  /// Recursively scan [directory] for audio files.
  Future<List<Map<String, dynamic>>> scan(Directory directory) async {
    final result = <Map<String, dynamic>>[];
    if (!directory.existsSync()) return result;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File || !isAudioFile(entity.path)) continue;
      final name = entity.uri.pathSegments.last;
      final parsed = parseName(name);
      result.add({
        'videoId': 'local://${entity.path}',
        'path': entity.path,
        'title': parsed.title,
        'artists': [
          {'name': parsed.artist}
        ],
        'status': 'LOCAL',
      });
    }
    result.sort((a, b) => a['title'].toString().compareTo(b['title'].toString()));
    return result;
  }
}
