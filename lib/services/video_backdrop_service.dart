import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player_win/video_player_win.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'media_player.dart';
import 'settings_manager.dart';
import 'stem_mixer_service.dart';
import '../ytmusic/ytmusic.dart';

/// Opt-in beta: a muted, looping canvas video behind the full-screen player,
/// mirroring the Android app's `CanvasArtworkPlayer`. The mobile app does not
/// play the whole song video in sync: it finds the official video, picks a
/// five-second clip from its centre and loops it silently behind the artwork.
///
/// The audio backend is never touched. The controller is created only while
/// the setting is on and the player page is open, and every failure is
/// contained here so only the backdrop disappears.
class VideoBackdropService extends ChangeNotifier {
  VideoBackdropService._();

  static final VideoBackdropService instance = VideoBackdropService._();

  WinVideoPlayerController? _controller;
  String? _videoId;
  String? _error;
  int _clipStartMs = 0;
  int _clipEndMs = 0;
  bool _busy = false;
  bool _attached = false;
  Timer? _loopTimer;

  WinVideoPlayerController? get controller => _controller;
  String? get error => _error;
  bool get busy => _busy;
  bool get hasVideo =>
      _controller != null && (_controller?.value.isInitialized ?? false);

  bool get enabled {
    if (!Platform.isWindows) return false;
    try {
      return GetIt.I.isRegistered<SettingsManager>() &&
          GetIt.I<SettingsManager>().extra<bool>('videoBackdropBeta', false);
    } catch (_) {
      return false;
    }
  }

  void attach() {
    _attached = true;
    onTrackChanged(_currentSong()?['videoId']?.toString());
  }

  void detach() {
    _attached = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    _disposeController();
    _error = null;
    notifyListeners();
  }

  void settingsChanged() {
    if (!enabled) {
      detach();
    } else if (_attached) {
      onTrackChanged(_currentSong()?['videoId']?.toString());
    }
  }

  Map<String, dynamic>? _currentSong() {
    if (!GetIt.I.isRegistered<MediaPlayer>()) return null;
    final item = GetIt.I<MediaPlayer>().currentSongNotifier.value;
    return item?.extras;
  }

  void onTrackChanged(String? videoId) {
    if (!_attached || !enabled) return;
    if (videoId == null || videoId.isEmpty) {
      _disposeController();
      notifyListeners();
      return;
    }
    if (_videoId == videoId && hasVideo) return;
    unawaited(_start(videoId));
  }

  /// Mirrors the mobile negative keyword filter: album tracks named "audio",
  /// "lyrics", "topic", etc. have a still cover as their video.
  static const List<String> nonVideoWords = [
    'audio only', 'official audio', 'lyrics', 'lyric video', 'topic',
    'visualizer', 'full audio', 'karaoke', 'slowed', 'sped up', 'nightcore',
    'reverb', 'lofi', 'lo-fi', '8d audio', 'cover', 'reaction',
  ];

  Future<String?> _officialVideoId(
      Map<String, dynamic> song, String fallback) async {
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ??
        (song['artists'] is List && (song['artists'] as List).isNotEmpty
            ? (song['artists'] as List).first['name']?.toString() ?? ''
            : '');
    if (title.isEmpty) return fallback;
    final clean = title.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ').trim();
    final lowerClean = clean.toLowerCase();
    if (nonVideoWords.any((w) => lowerClean.contains(w))) return null;
    try {
      final result = await GetIt.I<YTMusic>().search(
        '"$clean" $artist official music video',
        filter: 'videos',
        limit: 10,
      );
      for (final section in (result['sections'] as List? ?? const [])) {
        if (section is! Map) continue;
        for (final item in (section['items'] as List? ?? const [])) {
          if (item is! Map) continue;
          final id = item['videoId']?.toString() ?? '';
          final itemTitle = (item['title']?.toString() ?? '').toLowerCase();
          if (id.isEmpty || itemTitle.isEmpty) continue;
          if (nonVideoWords.any((w) => itemTitle.contains(w))) continue;
          final keywords = lowerClean
              .split(' ')
              .where((w) => w.length > 2 && RegExp(r'[a-z0-9]').hasMatch(w))
              .toList();
          final matches = keywords.isEmpty ||
              keywords.every((w) => itemTitle.contains(w));
          if (matches) return id;
        }
      }
    } catch (e) {
      debugPrint('[video backdrop] official video search failed: $e');
    }
    return null;
  }

  Future<void> _start(String videoId) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _disposeController();
    notifyListeners();
    final yt = YoutubeExplode();
    try {
      final song = _currentSong() ?? const <String, dynamic>{};
      final targetId = await _officialVideoId(song, videoId);
      if (targetId == null) throw 'no official video (album-track artwork)';
      final manifest = await yt.videos.streamsClient.getManifest(
        targetId,
        requireWatchPage: false,
        ytClients: [
          YoutubeApiClient.tvSimplyEmbedded,
          YoutubeApiClient.webCreator,
          YoutubeApiClient.androidVr,
        ],
      );
      final streams = <dynamic>[
        ...manifest.muxed,
        ...manifest.videoOnly,
      ];
      if (streams.isEmpty) throw 'no video stream available';
      // MP4 is decoded by Windows Media Foundation out of the box.
      dynamic chosen;
      for (final stream in streams) {
        if (stream.container == StreamContainer.mp4) {
          chosen = stream;
          break;
        }
      }
      chosen ??= streams.last;
      final controller = WinVideoPlayerController.networkUrl(
        Uri.parse(chosen.url.toString()),
      );
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!controller.value.isInitialized) {
        await controller.dispose();
        throw 'video could not be initialized';
      }
      await controller.setVolume(0);
      // Mobile: a 5-second clip from the centre of the video, looped.
      final total = controller.value.duration.inMilliseconds;
      _clipStartMs = ((total ~/ 2) - 2500).clamp(0, total);
      _clipEndMs = (_clipStartMs + 5000).clamp(0, total);
      if (_clipEndMs <= _clipStartMs) {
        _clipStartMs = 0;
        _clipEndMs = total;
      }
      await controller.seekTo(Duration(milliseconds: _clipStartMs));
      await controller.play();
      _controller = controller;
      _videoId = videoId;
      _startLoop();
    } catch (e) {
      _error = e.toString();
      debugPrint('[video backdrop] disabled for $videoId: $e');
      _disposeController();
    } finally {
      _busy = false;
      yt.close();
      notifyListeners();
    }
  }

  void _startLoop() {
    _loopTimer?.cancel();
    // Only video state is touched here: no audio seek, no stem changes.
    _loopTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final video = _controller;
      if (video == null || !video.value.isInitialized) return;
      final mixer = GetIt.I.isRegistered<StemMixerService>()
          ? StemMixerService.instance
          : null;
      final audioPlaying = mixer != null && mixer.state.stemsLoaded
          ? mixer.isPlaying
          : (GetIt.I.isRegistered<MediaPlayer>() &&
              GetIt.I<MediaPlayer>().player.playing);
      try {
        if (!audioPlaying && video.value.isPlaying) {
          unawaited(video.pause());
        } else if (audioPlaying && !video.value.isPlaying) {
          unawaited(video.play());
        }
        if (video.value.position.inMilliseconds >= _clipEndMs - 120) {
          unawaited(video.seekTo(Duration(milliseconds: _clipStartMs)));
        }
      } catch (e) {
        debugPrint('[video backdrop] loop skipped: $e');
      }
    });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _videoId = null;
    if (controller == null) return;
    try {
      unawaited(controller.pause());
    } catch (_) {}
    try {
      unawaited(controller.dispose());
    } catch (_) {}
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
