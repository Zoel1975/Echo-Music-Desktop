import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../generated/l10n.dart';
import '../services/bottom_message.dart';
import '../services/download_manager.dart';

/// Feedback for the song-menu "Download" action.
///
/// `DownloadManager.downloadSong` only logged failures with `debugPrint`, so a
/// failed download looked like a successful one and the user had no way to tell
/// whether the file was actually saved. This reports the real outcome once the
/// download finishes.
class DownloadFeedback {
  const DownloadFeedback._();

  static Future<void> download(
    ScaffoldMessengerState messenger,
    Map<dynamic, dynamic> song,
  ) async {
    final manager = GetIt.I<DownloadManager>();
    final videoId = song['videoId']?.toString();
    BottomMessage.showOn(
      messenger,
      S.current.Download_Started,
      duration: const Duration(seconds: 2),
    );
    try {
      await manager.downloadSong(Map<String, dynamic>.from(song));
    } catch (_) {
      // The status below is the source of truth.
    }
    final downloads = manager.downloads.value.whereType<Map>();
    Map? stored;
    for (final download in downloads) {
      if (download['videoId']?.toString() == videoId) {
        stored = download;
        break;
      }
    }
    if (stored != null && stored['status']?.toString() == 'DOWNLOADED') {
      BottomMessage.showOn(messenger, S.current.DownloadComplete);
    } else {
      final detail = manager.lastDownloadError;
      final message = (detail == null || detail.isEmpty)
          ? S.current.DownloadFailed
          : '${S.current.DownloadFailed}: ${detail.length > 140 ? '${detail.substring(0, 140)}…' : detail}';
      BottomMessage.showOn(messenger, message,
          duration: const Duration(seconds: 8));
    }
  }
}
