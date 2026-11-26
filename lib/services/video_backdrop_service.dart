import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player_win/video_player_win.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'media_player.dart';
import 'settings_manager.dart';
import 'stem_mixer_service.dart';
import 'stream_resolver.dart';

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
  String? get videoError => _controller?.value.errorDescription;
  bool get controllerPresent => _controller != null;
  bool get controllerPlaying => _controller?.value.isPlaying ?? false;
  int get controllerPositionMs =>
      _controller?.value.position.inMilliseconds ?? 0;
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
      YoutubeExplode yt, Map<String, dynamic> song, String fallback) async {
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
      // Use the resolver's own search: YTMusic.search applies the user's
      // "hide video songs" filter, which can hide every result we need.
      final videos = await yt.search('"$clean" $artist official music video');
      for (final item in videos) {
        final id = item.id.value;
        final itemTitle = item.title.toLowerCase();
        if (id.isEmpty || itemTitle.isEmpty) continue;
        if (nonVideoWords.any((w) => itemTitle.contains(w))) continue;
        final keywords = lowerClean
            .split(' ')
            .where((w) => w.length > 2 && RegExp(r'[a-z0-9]').hasMatch(w))
            .toList();
        final matches =
            keywords.isEmpty || keywords.every((w) => itemTitle.contains(w));
        if (matches) return id;
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
      final targetId = await _officialVideoId(yt, song, videoId);
      if (targetId == null) throw 'no official video (album-track artwork)';
      // Use the same anti-bot client chain as audio playback.
      final url = await StreamResolver.instance.resolveVideo(targetId);
      if (url == null || url.isEmpty) throw 'no video stream available';
      final controller = WinVideoPlayerController.networkUrl(Uri.parse(url));
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
          _safeVideo(() => video.pause());
        } else if (audioPlaying && !video.value.isPlaying) {
          _safeVideo(() => video.play());
        }
        if (video.value.position.inMilliseconds >= _clipEndMs - 120) {
          _safeVideo(() => video.seekTo(Duration(milliseconds: _clipStartMs)));
        }
      } catch (e) {
        debugPrint('[video backdrop] loop skipped: $e');
      }
    });
  }

  /// The Windows controller throws synchronously when the file was never
  /// opened (e.g. a stream failed). Wrap every call in an async closure so a
  /// sync throw cannot escape as an uncaught error.
  void _safeVideo(Future<void> Function() action) {
    unawaited(() async {
      try {
        await action();
      } catch (e) {
        debugPrint('[video backdrop] ignored: $e');
      }
    }());
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _videoId = null;
    if (controller == null) return;
    _safeVideo(() async {
      try {
        await controller.pause();
      } catch (_) {}
      await controller.dispose();
    });
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
