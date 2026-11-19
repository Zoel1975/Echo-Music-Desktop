/// Ports of `youtube/YouTubeLyricsProvider.kt` and
/// `youtube/YouTubeSubtitleLyricsProvider.kt`, using the desktop
/// `YTClient.getLyricsForVideo` (InnerTube `next` → `get_lyrics` /
/// `get_transcript`).
import 'package:get_it/get_it.dart';

import 'lyrics_registry.dart';
import '../ytmusic/ytmusic.dart';

class YouTubeMusicProvider extends LyricsProvider {
  @override
  String get name => 'YouTubeMusic';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final lrc = await GetIt.I<YTMusic>().getLyricsForVideo(id);
    if (lrc == null || lrc.isEmpty) return null;
    return LyricsProviderResult(syncedLyrics: lrc);
  }
}

class YouTubeSubtitleProvider extends LyricsProvider {
  @override
  String get name => 'YouTubeSubtitle';

  @override
  Future<LyricsProviderResult?> getLyrics({
    required String id,
    required String title,
    required String artist,
    required int duration,
    String? album,
  }) async {
    final lrc = await GetIt.I<YTMusic>().getLyricsForVideo(id, transcript: true);
    if (lrc == null || lrc.isEmpty) return null;
    return LyricsProviderResult(syncedLyrics: lrc);
  }
}
