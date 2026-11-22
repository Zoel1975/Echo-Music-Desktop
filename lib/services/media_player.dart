import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Echo/services/audio_source_info.dart';
import 'package:Echo/services/crossfade_engine.dart';
import 'package:Echo/services/desktop_dsp.dart';
import 'package:Echo/services/playback_cutoff.dart';
import 'package:Echo/services/scrobble_service.dart';
import 'package:Echo/services/discord_rpc_service.dart';
import 'package:Echo/services/listen_together_service.dart';
import 'package:Echo/services/queue_crossfade.dart';
import 'package:Echo/services/sponsor_block_service.dart';
import 'package:Echo/services/stream_resolver.dart';
import 'package:Echo/services/extension_quality.dart';
import 'package:Echo/services/monochrome_audio_source.dart';
import 'package:Echo/services/monochrome_service.dart';
import 'package:Echo/services/yt_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/add_history.dart';
import '../ytmusic/ytmusic.dart';
import 'settings_manager.dart';
import 'queue_snapshot.dart';
import 'sleep_timer.dart';

/// Hive box used by `MediaPlayer` for `STATE` — see `saveState`/`restoreLastPlayed`.
Box _queueBox = Hive.box('QUEUE');

class MediaPlayer extends ChangeNotifier {
  late final AudioPlayer _player;

  final ValueNotifier<String?> playbackError = ValueNotifier<String?>(null);

  /// Effective format/source of the playing track, updated when the audio
  /// source is created and again when a stream resolves (real codec/bitrate).
  final ValueNotifier<PlaybackSourceInfo?> playbackSource =
      ValueNotifier<PlaybackSourceInfo?>(null);

  final _loudnessEnhancer = AndroidLoudnessEnhancer();
  AndroidEqualizer? _equalizer;
  AndroidEqualizerParameters? _equalizerParams;

  List<IndexedAudioSource> _songList = [];
  final ValueNotifier<MediaItem?> _currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _currentIndex = ValueNotifier(null);
  final ValueNotifier<ButtonState> _buttonState =
      ValueNotifier(ButtonState.loading);
  late final SleepTimer sleepTimer;

  final ValueNotifier<LoopMode> _loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<ProgressBarState> _progressBarState =
      ValueNotifier(ProgressBarState());

  bool _shuffleModeEnabled = false;

  bool autoFetching = false;

  /// Monotonic generation for every user-initiated play request. A newer
  /// request invalidates the older one at every await point, so two rapid
  /// clicks can never interleave stop/load/play on the same AudioPlayer.
  int _playGeneration = 0;

  MediaPlayer() {
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
    }
    final AudioPipeline pipeline = AudioPipeline(
      androidAudioEffects: [
        if (Platform.isAndroid && _equalizer != null) _equalizer!,
        _loudnessEnhancer,
      ],
    );
    _player = AudioPlayer(audioPipeline: pipeline);
    sleepTimer = SleepTimer(_JustAudioSleepTarget(_player));
    sleepTimer.addListener(notifyListeners);
    // Every path that changes the current song (queue, crossfade, restore,
    // retry) goes through this notifier, so the source label stays in sync.
    _currentSongNotifier.addListener(_syncSourceInfoFromCurrent);

    GetIt.I.registerSingleton<AndroidLoudnessEnhancer>(_loudnessEnhancer);
    if (Platform.isAndroid && _equalizer != null) {
      GetIt.I.registerSingleton<AndroidEqualizer>(_equalizer!);
      print(GetIt.I<AndroidEqualizer>());
    }

    _init();
  }

  AudioPlayer get player => _player;
  List<IndexedAudioSource> get songList => List.unmodifiable(_songList);
  ValueNotifier<MediaItem?> get currentSongNotifier => _currentSongNotifier;
  ValueNotifier<int?> get currentIndex => _currentIndex;
  ValueNotifier<ButtonState> get buttonState => _buttonState;
  ValueNotifier<ProgressBarState> get progressBarState => _progressBarState;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  ValueNotifier<LoopMode> get loopMode => _loopMode;
  ValueNotifier<Duration?> get timerDuration => sleepTimer.remaining;

  Stream<
      ({
        List<IndexedAudioSource>? sequence,
        int? currentIndex,
        MediaItem? currentItem
      })> get currentTrackStream => Rx.combineLatest2<
          List<IndexedAudioSource>?,
          int?,
          ({
            List<IndexedAudioSource>? sequence,
            int? currentIndex,
            MediaItem? currentItem
          })>(
        _player.sequenceStream,
        _player.currentIndexStream,
        (sequence, currentIndex) {
          MediaItem? currentItem;
          if (sequence != null &&
              currentIndex != null &&
              currentIndex >= 0 &&
              currentIndex < sequence.length) {
            final tag = sequence[currentIndex].tag;
            if (tag is MediaItem) currentItem = tag;
          }
          return (
            sequence: sequence,
            currentIndex: currentIndex,
            currentItem: currentItem,
          );
        },
      );

  Future<void> _init() async {
    await _loadLoudnessEnhancer();
    await _loadEqualizer();

    _listenToChangesInPlaylist();
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    _listenToShuffle();
    _listenToAutofetch();
    _listenToPlayerErrors();

    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentSongNotifier.value != null && _player.playing) {
        GetIt.I<YTMusic>()
            .addPlayingStats(currentSongNotifier.value!.id, _player.position);
      }
    });
  }

  Future<void> _loadLoudnessEnhancer() async {
    await _loudnessEnhancer
        .setEnabled(GetIt.I<SettingsManager>().loudnessEnabled);

    await _loudnessEnhancer
        .setTargetGain(GetIt.I<SettingsManager>().loudnessTargetGain);
  }

  Future<void> _loadEqualizer() async {
    if (!Platform.isAndroid || _equalizer == null) return;
    await _equalizer!.setEnabled(GetIt.I<SettingsManager>().equalizerEnabled);
    _equalizer!.parameters.then((value) async {
      _equalizerParams ??= value;
      final List<AndroidEqualizerBand> bands = _equalizerParams!.bands;
      if (GetIt.I<SettingsManager>().equalizerBandsGain.isEmpty) {
        GetIt.I<SettingsManager>().equalizerBandsGain =
            List.generate(bands.length, (index) => 0.0);
      }

      List<double> equalizerBandsGain =
          GetIt.I<SettingsManager>().equalizerBandsGain;
      for (var e in bands) {
        final gain =
            equalizerBandsGain.isNotEmpty ? equalizerBandsGain[e.index] : 0.0;
        _equalizerParams!.bands[e.index].setGain(gain);
      }
    });
  }

  Future<void> setLoudnessEnabled(bool value) async {
    // Applied natively where supported (Android); a no-op elsewhere, but the
    // setting is honoured so desktop can apply its own gain path.
    try {
      await _loudnessEnhancer.setEnabled(value);
    } catch (_) {}
    GetIt.I<SettingsManager>().loudnessEnabled = value;
  }

  Future<void> setEqualizerEnabled(bool value) async {
    await _equalizer?.setEnabled(value);
    GetIt.I<SettingsManager>().equalizerEnabled = value;
  }

  Future<void> setLoudnessTargetGain(double value) async {
    try {
      await _loudnessEnhancer.setTargetGain(value);
    } catch (_) {}
    GetIt.I<SettingsManager>().loudnessTargetGain = value;
  }

  void _listenToChangesInPlaylist() {
    _player.sequenceStream.listen((playlist) {
      final List<IndexedAudioSource> newList =
          (playlist).cast<IndexedAudioSource>();

      if (listEquals(newList, _songList)) return;

      final bool shouldAdd = (_songList.isEmpty && newList.isNotEmpty);

      if (newList.isEmpty) {
        _currentSongNotifier.value = null;
        _currentIndex.value = null;
        _songList = [];
      } else {
        _songList = newList;

        _currentIndex.value ??= 0;
        _currentSongNotifier.value =
            (_songList.length > (_currentIndex.value ?? 0))
                ? _songList[_currentIndex.value ?? 0].tag
                : null;
      }

      if (shouldAdd == true && _currentSongNotifier.value != null) {
        addHistory(_currentSongNotifier.value!.extras!);
      }

      notifyListeners();
      unawaited(saveState());
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((event) {
      final isPlaying = event.playing;
      final processingState = event.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        _buttonState.value = ButtonState.loading;
      } else if (processingState == ProcessingState.ready) {
        _buttonState.value =
            isPlaying ? ButtonState.playing : ButtonState.paused;
      } else if (processingState == ProcessingState.completed) {
        unawaited(scrobbleCompleted());
        sleepTimer.onPlaybackCompleted();
        _player.seek(Duration.zero);
        _player.pause();
        _buttonState.value = ButtonState.paused;
      } else {
        // idle state
        _buttonState.value = ButtonState.paused;
      }
      if (processingState != ProcessingState.loading &&
          processingState != ProcessingState.buffering) {
        unawaited(saveState());
      }
    });
  }

  void _listenToPlayerErrors() {
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        // Surface the failure to the UI instead of failing silently.
        playbackError.value = 'Playback error: ${e.toString()}';
        _buttonState.value = ButtonState.paused;
        notifyListeners();
        // Android `auto_skip_next_on_error`: skip to the next queued track
        // when enabled so playback stays continuous after a failed source.
        if (GetIt.I<SettingsManager>().autoSkipOnError &&
            (_player.currentIndex ?? -1) + 1 < _songList.length) {
          unawaited(_player.seekToNext());
        }
      },
    );
  }

  /// Persists the full queue (all songs, current index, position, playing
  /// state) so a restart restores exactly what was playing — Android's
  /// `MusicService` queue persistence.
  Future<void> saveState() async {
    final sequence = _player.sequence;
    if (sequence.isEmpty) return;
    final songs = <Map<String, dynamic>>[];
    for (final source in sequence) {
      final tag = source.tag;
      if (tag is MediaItem) {
        songs.add(Map<String, dynamic>.from(tag.extras ?? {'videoId': tag.id}));
      }
    }
    if (songs.isEmpty) return;
    final snapshot = QueueSnapshot(
      songs: songs,
      index: _player.currentIndex ?? 0,
      positionMs: _player.position.inMilliseconds,
      wasPlaying: _player.playing,
    );
    await _queueBox.put('STATE', snapshot.toMap());
  }

  /// Rebuilds the queue from the last saved snapshot and resumes the same
  /// track/position (and playback state) on launch.
  Future<void> restoreLastPlayed() async {
    final raw = _queueBox.get('STATE');
    if (raw == null) return;
    final snapshot = QueueSnapshot.fromMap(raw);
    if (!snapshot.isValid) return;
    try {
      final sources = <AudioSource>[];
      for (final song in snapshot.songs) {
        sources.add(await _getAudioSource(song));
      }
      if (sources.isEmpty) return;
      await _player.setAudioSources(
        sources,
        initialIndex: snapshot.index,
        initialPosition: Duration.zero,
      );
      if (snapshot.positionMs > 0) {
        await _player.seek(
          Duration(milliseconds: snapshot.positionMs),
          index: snapshot.index,
        );
      }
      if (snapshot.wasPlaying) await _player.play();
    } catch (e) {
      debugPrint('Could not restore the playback queue: $e');
      await _queueBox.delete('STATE');
    }
  }

  final SponsorBlockService _sponsorBlock = SponsorBlockService();

  // Two-player crossfade: a dedicated outgoing player overlaps the previous
  // track with the new one on user-initiated track switches.
  AudioPlayer? _xfadeOutPlayer;
  QueueCrossfadeController? _xfade;
  bool _xfadeArmed = false;
  int? _xfadeArmedIndex;

  void _listenToCurrentPosition() {
    _player.positionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.current != position) {
        _progressBarState.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total,
        );
      }
      _maybeSkipSponsor(position);
      _maybePreArmQueueCrossfade(position);
    });
  }

  /// Automatic queue advance: when the current track is within the crossfade
  /// window of its end and a next track is queued, overlap them using a
  /// dedicated outgoing player + equal-power ramp instead of a hard cut.
  Future<void> _maybePreArmQueueCrossfade(Duration position) async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled) return;
    final idx = _player.currentIndex;
    if (idx == null) return;
    if (_xfadeArmedIndex == idx) return; // already armed for this track
    final nextIdx = idx + 1;
    final hasNext = nextIdx < _songList.length;
    final decision = QueueEndCrossfade.evaluate(
      position: position,
      duration: _player.duration,
      crossfade: Duration(
          milliseconds: (settings.crossfadeDuration * 1000).round()),
      enabled: settings.crossfadeEnabled,
      hasNext: hasNext,
      alreadyArmed: _xfadeArmedIndex == idx,
    );
    // Adaptive pre-arm: also fire when buffering is thin near the end, even
    // if crossfade itself is off (Android AdaptivePreArmManager).
    final cutoffArm = PlaybackCutoffGuard.shouldPreArm(
      positionMs: position.inMilliseconds,
      durationMs: (_player.duration ?? Duration.zero).inMilliseconds,
      bufferedMs: _player.bufferedPosition.inMilliseconds,
      baseLeadMs: (settings.crossfadeDuration * 1000).round(),
    );
    if (!decision.shouldArm && !cutoffArm) return;
    _xfadeArmed = true;
    _xfadeArmedIndex = idx;

    try {
      final currentTag = _songList[idx].tag;
      final nextTag = _songList[nextIdx].tag;
      if (currentTag is! MediaItem || nextTag is! MediaItem) return;
      final outPlayer = _xfadeOutPlayer ??= AudioPlayer();
      _xfade?.dispose();
      _xfade = QueueCrossfadeController(makePlayer: () => AudioPlayerAdapter(outPlayer));
      final outSource = await _getAudioSource(currentTag.extras ?? {});
      await outPlayer.setAudioSource(outSource);
      await outPlayer.seek(position);
      await outPlayer.setVolume(1.0);
      await outPlayer.play();

      // Seek the main player to the next track (queue preserved) and ramp it in.
      await _player.setVolume(0);
      await _player.seek(Duration.zero, index: nextIdx);
      _currentSongNotifier.value = nextTag;
      _currentIndex.value = nextIdx;
      await _player.play();

      await _xfade!.start(
        incoming: AudioPlayerAdapter(_player),
        duration: Duration(milliseconds: (settings.crossfadeDuration * 1000).round()),
        peakVolume: _dspTargetGain,
        startOutgoing: (_) async {},
        onDone: () {
          outPlayer.stop();
          _player.setVolume(_dspTargetGain);
        },
      );
    } catch (e) {
      debugPrint('Queue-end crossfade failed: $e');
      _xfade?.cancel();
      _xfadeArmed = false;
      _xfadeArmedIndex = null;
    }
  }

  /// Android SponsorBlock auto-skip: when the enabled setting is on, fetch
  /// segments for the current track and seek past a segment we just entered.
  void _maybeSkipSponsor(Duration position) {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.sponsorBlock) return;
    final song = _currentSongNotifier.value;
    final videoId = song?.id;
    if (videoId == null || videoId.startsWith('local://')) return;
    final seconds = position.inMilliseconds / 1000.0;
    _sponsorBlock.getSegments(videoId).then((segments) {
      final seg = SponsorBlockService.segmentAt(segments, seconds);
      if (seg != null && _player.playing) {
        unawaited(_player.seek(Duration(milliseconds: (seg.end * 1000).toInt() + 50)));
      }
    });
  }

  void _listenToBufferedPosition() {
    _player.bufferedPositionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.buffered != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: position,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToTotalDuration() {
    _player.durationStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.total != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: position ?? Duration.zero,
        );
      }
    });
  }

  void _listenToShuffle() {
    _player.shuffleModeEnabledStream.listen((data) {
      _shuffleModeEnabled = data;
      notifyListeners();
    });
  }

  void _listenToChangesInSong() {
    _player.currentIndexStream.listen((index) {
      sleepTimer.onMediaItemTransition();
      if (_songList.isNotEmpty && _currentIndex.value != index) {
        _currentIndex.value = index;
        _currentSongNotifier.value =
            index != null && _songList.isNotEmpty && index < _songList.length
                ? _songList[index].tag
                : null;
        if (_songList.isNotEmpty && _currentIndex.value != null) {
          final MediaItem item = _songList[_currentIndex.value!].tag;
          addHistory(item.extras!);
        }
        notifyListeners();
        unawaited(saveState());
      }
    });
  }

  void changeLoopMode() {
    switch (_loopMode.value) {
      case LoopMode.off:
        _loopMode.value = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode.value = LoopMode.one;
        break;
      default:
        _loopMode.value = LoopMode.off;
        break;
    }
    _player.setLoopMode(_loopMode.value);
  }

  Future<void> skipSilence(bool value) async {
    // just_audio degrades gracefully where skip-silence is unsupported, so
    // the toggle is applied on every platform rather than guarded by Android.
    await _player.setSkipSilenceEnabled(value);
    GetIt.I<SettingsManager>().skipSilence = value;
  }

  /// Records the effective source on the source's tag (survives queue
  /// switches) and, when it is the playing song, in the player UI notifier.
  void _setSourceInfo(Object? tag, PlaybackSourceInfo info) {
    if (tag is! MediaItem) return;
    final extras = tag.extras;
    if (extras != null) {
      extras['echoSourceFormat'] = info.format;
      extras['echoSourceName'] = info.source;
      extras['echoSourceDetail'] = info.detail ?? '';
    }
    if (tag.id != null && tag.id == _currentSongNotifier.value?.id) {
      playbackSource.value = info;
    }
  }

  /// Restores the label stored on a tag when the current track changes.
  void _syncSourceInfoFromCurrent() {
    final extras = _currentSongNotifier.value?.extras;
    if (extras == null) {
      playbackSource.value = null;
      return;
    }
    playbackSource.value = PlaybackSourceInfo(
      format: extras['echoSourceFormat']?.toString() ?? 'Audio',
      source: extras['echoSourceName']?.toString() ?? 'YouTube',
      detail: extras['echoSourceDetail']?.toString(),
    );
  }

  Future<AudioSource> _getAudioSource(Map<String, dynamic> song) async {
    MediaItem tag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: (song['thumbnails'] is List && song['thumbnails'].isNotEmpty)
          ? Uri.tryParse(song['thumbnails'].first['url']?.toString() ?? '')
          : null,
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      // Copy: source metadata is added below without mutating the library map.
      extras: <String, dynamic>{...song},
    );

    final bool isDownloaded =
        (song['status'] == 'DOWNLOADED' || song['status'] == 'LOCAL') &&
            song['path'] != null &&
            (await File(song['path']).exists());

    if (isDownloaded) {
      final path = song['path'].toString();
      final ext = path.contains('.') ? path.split('.').last.toUpperCase() : '';
      _setSourceInfo(
        tag,
        PlaybackSourceInfo(
          format: ext.isEmpty ? 'File' : ext,
          source: 'File locale',
        ),
      );
      return AudioSource.file(song['path'], tag: tag);
    } else {
      // Data Saver forces the low-bitrate stream (Android's Wi-Fi/Cellular
      // quality ceiling, adapted for desktop).
      final settings = GetIt.I<SettingsManager>();
      final quality = ExtensionQuality.resolve(
        dataSaver: settings.dataSaver,
        // Android ExtensionManager "high quality (320 kbps)" toggle.
        highQuality: settings.extra<bool>('highQuality', false),
        configured: settings.streamingQuality.name.toLowerCase(),
      );
      // FLAC quality (Monochrome public API): find a lossless match for the
      // current song and stream it with seekable range requests. If Monochrome
      // has no match (or is rate-limited/unavailable), fall back to YouTube.
      if (quality == 'flac') {
        final track = await MonochromeService.findBySong(song);
        if (track != null) {
          _setSourceInfo(
            tag,
            const PlaybackSourceInfo(format: 'FLAC', source: 'Monochrome'),
          );
          // Best-effort STREAMINFO probe: reveals real Hz/bit depth when the
          // CDN allows it; the plain label stays when it is rate-limited.
          unawaited(MonochromeService.probeFlacInfo(track).then((info) {
            if (info != null) {
              _setSourceInfo(
                tag,
                PlaybackSourceInfo(
                  format: 'FLAC',
                  source: 'Monochrome',
                  detail: info.label,
                ),
              );
            }
          }));
          return MonochromeAudioSource(
            track: track,
            fallbackVideoId: song['videoId']?.toString() ?? '',
            onFallback: () => _setSourceInfo(
              tag,
              const PlaybackSourceInfo(format: 'Opus', source: 'YouTube'),
            ),
            onFallbackResolved: (mime, bitrate) => _setSourceInfo(
              tag,
              PlaybackSourceInfo.fromStream(mime, bitrate),
            ),
            tag: tag,
          );
        }
      }
      // Use direct URL approach for macOS for better compatibility with AVFoundation
      if (Platform.isMacOS) {
        return await getDirectUrlAudioSource(
          song['videoId'],
          quality,
          tag,
          onResolved: (stream) => _setSourceInfo(
            tag,
            PlaybackSourceInfo.fromStream(stream.mimeType, stream.bitrate),
          ),
        );
      }
      _setSourceInfo(
        tag,
        const PlaybackSourceInfo(format: 'Opus', source: 'YouTube'),
      );
      return YouTubeAudioSource(
        videoId: song['videoId'],
        quality: quality,
        onResolved: (stream) => _setSourceInfo(
          tag,
          PlaybackSourceInfo.fromStream(stream.mimeType, stream.bitrate),
        ),
        tag: tag,
      );
    }
  }

  int _lastPlayRequestId = 0;

  /// Play a local audio file (Android `LocalSongScreen` tap). Reuses the
  /// local-file branch of [_getAudioSource] via `status: LOCAL` + `path`.
  Future<void> playLocalFile(Map<String, dynamic> song) async {
    final path = song['path']?.toString();
    if (path == null || !File(path).existsSync()) return;
    final localSong = Map<String, dynamic>.from(song)
      ..['status'] = 'LOCAL'
      ..['videoId'] = song['videoId'] ?? 'local://$path';
    await playSong(localSong);
  }

  Future<void> playSong(Map<String, dynamic> song) async {
    if (song['videoId'] == null) return;

    // Generate a new request ID (monotonic: two taps in the same millisecond
  // used to get the same id and both continued playing).
    final int requestId = ++_playGeneration;
    _lastPlayRequestId = requestId;

    // Capture what is currently playing for a possible crossfade handoff.
    final wasPlaying = _player.playing;
    final previousSong = _currentSongNotifier.value?.extras;
    final previousPosition = _player.position;
    final settings = GetIt.I<SettingsManager>();
    final decision = CrossfadeDecision.evaluate(
      crossfadeEnabled: settings.crossfadeEnabled,
      wasPlaying: wasPlaying,
      userVolume: _player.volume,
      targetGain: settings.loudnessEnabled
          ? (settings.loudnessTargetGain / 20).clamp(0.3, 1.0)
          : 1.0,
    );

    // OPTIMISTIC UPDATE: Show miniplayer immediately with loading state
    MediaItem tempTag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: (song['thumbnails'] is List && song['thumbnails'].isNotEmpty)
          ? Uri.tryParse(song['thumbnails'].first['url']?.toString() ?? '')
          : null,
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );
    _currentSongNotifier.value = tempTag;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      final source = await _getAudioSource(song);
      if (_lastPlayRequestId != requestId)
        return; // Stale request, user clicked something else

      if (decision.enabled && previousSong != null) {
        // Real two-player crossfade: keep the outgoing track audible on a
        // dedicated player while the new track fades in on the main player.
        await _crossfadeTo(
          requestId: requestId,
          source: source,
          previousSong: Map<String, dynamic>.from(previousSong as Map),
          previousPosition: previousPosition,
          peakVolume: decision.peakVolume,
          duration: Duration(
              milliseconds: (settings.crossfadeDuration * 1000).round()),
        );
        return;
      }

      // stop and set the tapped song as the single source so it plays immediately
      await _player.pause();
      await _player.stop();
      if (_lastPlayRequestId != requestId) return; // Stale request
      await _player.clearAudioSources();
      if (_lastPlayRequestId != requestId) return; // Stale request
      await _player.setAudioSource(source);
      if (_lastPlayRequestId != requestId) return;
      await _player.play();
      // Apply the real crossfade envelope: when crossfade is enabled the new
      // track fades in from silence over the configured duration (equal-power
      // curve), giving a smooth blend instead of an abrupt start.
      unawaited(_applyTrackFadeIn());
      unawaited(reportIntegrationsNowPlaying());
    } catch (e) {
      if (_lastPlayRequestId == requestId) {
        print("Error playing song: $e");
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
    }
  }

  /// Performs a real equal-power crossfade between the outgoing track (on a
  /// dedicated player) and [source] (on the main player).
  Future<void> _crossfadeTo({
    required int requestId,
    required AudioSource source,
    required Map<String, dynamic> previousSong,
    required Duration previousPosition,
    required double peakVolume,
    required Duration duration,
  }) async {
    _xfade?.dispose();
    final outPlayer = _xfadeOutPlayer ??= AudioPlayer();
    _xfade = QueueCrossfadeController(
      makePlayer: () => AudioPlayerAdapter(outPlayer),
    );

    await _player.pause();
    await _player.stop();
    await _player.clearAudioSources();
    if (_lastPlayRequestId != requestId) return;

    // Attach + position the outgoing track on the dedicated player.
    final outSource = await _getAudioSource(previousSong);
    await outPlayer.setAudioSource(outSource);
    await outPlayer.seek(previousPosition);
    await outPlayer.setVolume(peakVolume);

    // Load the incoming track at silence and start the ramp.
    await _player.setAudioSource(source);
    if (_lastPlayRequestId != requestId) return;
    await _player.setVolume(0);
    await _player.play();

    await _xfade!.start(
      incoming: AudioPlayerAdapter(_player),
      duration: duration,
      peakVolume: peakVolume,
      startOutgoing: (_) async {}, // already attached/positioned above
      onDone: () {
        outPlayer.stop();
        // Restore normal volume for subsequent tracks.
        _player.setVolume(peakVolume);
      },
    );
  }

  /// Re-attach the current audio source so a newly-applied mpv filter (e.g.
  /// silenceremove) takes effect on desktop. Restores playback position.
  Future<void> reloadCurrentSource() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    final idx = _player.currentIndex;
    final song = _currentSongNotifier.value?.extras;
    if (idx == null || song == null) return;
    final position = _player.position;
    final wasPlaying = _player.playing;
    try {
      final source = await _getAudioSource(Map<String, dynamic>.from(song as Map));
      await _player.pause();
      await _player.stop();
      await _player.clearAudioSources();
      await _player.setAudioSource(source);
      await _player.seek(position);
      if (wasPlaying) await _player.play();
    } catch (e) {
      debugPrint('reloadCurrentSource failed: $e');
    }
  }

  Future<void> playNext(Map<String, dynamic> mediaItem) async {
    // Case 1: A single video/song
    if (mediaItem['videoId'] != null) {
      final audioSource = await _getAudioSource(mediaItem);

      // Determine insertion position
      final currentIndex = _player.currentIndex ?? -1;
      final sequenceLength = _player.sequence.length;
      final insertIndex = (currentIndex + 1).clamp(0, sequenceLength);

      // If player already has something in the queue
      if (sequenceLength > 0) {
        await _player.insertAudioSource(insertIndex, audioSource);
      } else {
        // If queue is empty, just set and start playing
        await _player.setAudioSource(audioSource);
      }

      // Case 2: Custom or Downloaded Playlist
    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      await _addSongListToQueue(songs, isNext: true);

      // Case 3: Online Playlist
    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      await _addSongListToQueue(songs, isNext: true);
    }
  }

  Future<void> playAll(List songs, {int index = 0}) async {
    if (songs.isEmpty) return;
    final generation = ++_playGeneration;
    _lastPlayRequestId = generation;
    playbackError.value = null;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      await _player.stop();
      if (generation != _playGeneration) return;
      // stop() does NOT clear a ConcatenatingAudioSource: without this the
      // previous playlist's tracks remained appended after the new one.
      await _player.clearAudioSources();
      if (generation != _playGeneration) return;

      // Build the ENTIRE playlist queue in one pass, starting at the tapped
      // track. YouTubeAudioSource is lazy, so this does not resolve any stream
      // until a track actually plays - unlike the old incremental add loop
      // which raced with play() and left a partial queue.
      final sources = <AudioSource>[];
      for (final song in songs) {
        if (generation != _playGeneration) return;
        sources.add(await _getAudioSource(Map<String, dynamic>.from(song)));
      }
      if (generation != _playGeneration || sources.isEmpty) return;

      final start = index.clamp(0, sources.length - 1);
      await _player.setAudioSources(sources, initialIndex: start);
      if (generation != _playGeneration) return;

      // Await play(): starting it while the previous load is still settling
      // was a frequent cause of "button pressed but nothing happens".
      await _player.play();
      if (generation != _playGeneration) return;
      _buttonState.value = ButtonState.playing;
      notifyListeners();
      unawaited(reportIntegrationsNowPlaying());
    } catch (e) {
      if (generation == _playGeneration) {
        debugPrint('Error in playAll: $e');
        playbackError.value = 'Riproduzione non riuscita: $e';
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
    }
  }

  // Lazy loading: only add next few songs, not entire playlist
  Future<void> _addRemainingToPlaylist(
    List songs,
    int playedIndex, [
    int? generation,
  ]) async {
    // The whole playlist becomes the queue, like Android. YouTubeAudioSource
    // is lazy (it resolves the stream only when that track is played), so
    // adding every track costs no extra network requests.
    final maxPreload = songs.length;
    var attempted = 0;
    var added = 0;
    for (var i = playedIndex + 1;
        i < songs.length && attempted < maxPreload + 2;
        i++) {
      if (generation != null && generation != _playGeneration) return;
      attempted++;
      try {
        final source =
            await _getAudioSource(Map<String, dynamic>.from(songs[i]));
        if (generation != null && generation != _playGeneration) return;
        await _player.addAudioSource(source);
        added++;
        if (added >= maxPreload) break;
      } catch (e) {
        debugPrint('Could not preload track ${songs[i]['videoId']}: $e');
        // Keep trying the following tracks.
      }
    }
  }

  Future<void> addToQueue(Map<String, dynamic> mediaItem) async {
    // Case 1: A single video/song
    if (mediaItem['videoId'] != null) {
      await _player.addAudioSource(await _getAudioSource(mediaItem));

      // Case 2: Custom or Downloaded Playlist
    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      await _addSongListToQueue(songs, isNext: false);

      // Case 3: Online Playlist
    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      await _addSongListToQueue(songs, isNext: false);
    }
  }

  Future<void> startRelated(Map<String, dynamic> song,
      {bool radio = false, bool shuffle = false, bool isArtist = false}) async {
    await _player.clearAudioSources();
    if (!isArtist) {
      await addToQueue(song);
    }
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        videoId: song['videoId'],
        playlistId: song['playlistRadioId'],
        radio: radio,
        shuffle: shuffle);
    if (songs.isNotEmpty) songs.removeAt(0);
    await _addSongListToQueue(songs, isNext: false);
    await _player.play();
  }

  Future<void> startPlaylistSongs(Map endpoint) async {
    await _player.clearAudioSources();
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        playlistId: endpoint['playlistId'], params: endpoint['params']);

    if (songs.isNotEmpty && songs.first['videoId'] == null) {
      // if API returned a placeholder, convert or handle accordingly
    }

    await _addSongListToQueue(songs);
    await _player.play();
  }

  /// Report the current track to configured integrations (Last.fm /
  /// ListenBrainz "now playing" and Discord RPC) using in-app entered tokens.
  Future<void> reportIntegrationsNowPlaying() async {
    final settings = GetIt.I<SettingsManager>();
    final tag = _currentSongNotifier.value;
    if (tag == null) return;
    final artist = tag.artist ?? '';
    final track = tag.title ?? '';
    final album = tag.album ?? '';

    // Last.fm now playing (requires user session key stored as apiKey field).
    if (settings.extra<bool>('lastfmNowPlaying', false)) {
      final apiKey = settings.extra<String>('lastfmApiKey', '');
      final session = settings.extra<String>('lastfmSessionKey', '');
      final secret = settings.extra<String>('lastfmApiSecret', '');
      if (apiKey.isNotEmpty && session.isNotEmpty && secret.isNotEmpty) {
        unawaited(GetIt.I<ScrobbleService>().sendNowPlaying(
          apiKey: apiKey,
          sessionKey: session,
          secret: secret,
          artist: artist,
          track: track,
          album: album,
        ));
      }
    }
    // ListenBrainz playing-now.
    if (settings.extra<bool>('listenbrainzScrobble', false)) {
      final token = settings.extra<String>('listenbrainzToken', '');
      if (token.isNotEmpty) {
        unawaited(GetIt.I<ScrobbleService>().submitListenBrainz(
          token: token,
          artist: artist,
          track: track,
          album: album,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          singleRelease: false,
        ));
      }
    }
    // Discord RPC.
    if (settings.extra<bool>('discordEnabled', false)) {
      final token = settings.extra<String>('discordToken', '');
      final clientId = settings.extra<String>('discordClientId', '');
      final rpc = GetIt.I<DiscordRpcService>();
      if (token.isNotEmpty && clientId.isNotEmpty && !rpc.isConnected) {
        await rpc.connect(clientId: clientId, accessToken: token);
      }
      await rpc.setActivity(
        name: settings.extra<String>('discordActivityName', 'Echo Music'),
        details: track,
        state: artist,
        activityType: settings.extra<String>('discordActivityType', 'Listening'),
        showWhenPaused:
            settings.extra<bool>('discordShowPaused', false),
      );
    }
    // Listen Together: publish playback state to the local room.
    if (settings.extra<bool>('ltTopBar', false)) {
      final lt = GetIt.I<ListenTogetherService>();
      if (!lt.isHosting) {
        await lt.startHosting(
            settings.extra<String>('ltUsername', 'Listener'));
      }
      lt.publishState(ListenState(
        username: settings.extra<String>('ltUsername', 'Listener'),
        songId: tag.id,
        title: track,
        positionMs: _player.position.inMilliseconds,
        playing: _player.playing,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  /// Scrobble a completed track to Last.fm / ListenBrainz.
  Future<void> scrobbleCompleted() async {
    final settings = GetIt.I<SettingsManager>();
    final tag = _currentSongNotifier.value;
    if (tag == null) return;
    final artist = tag.artist ?? '';
    final track = tag.title ?? '';
    final album = tag.album ?? '';
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (settings.extra<bool>('lastfmScrobble', false)) {
      final apiKey = settings.extra<String>('lastfmApiKey', '');
      final session = settings.extra<String>('lastfmSessionKey', '');
      final secret = settings.extra<String>('lastfmApiSecret', '');
      if (apiKey.isNotEmpty && session.isNotEmpty && secret.isNotEmpty) {
        unawaited(GetIt.I<ScrobbleService>().scrobbleLastfm(
          apiKey: apiKey,
          sessionKey: session,
          secret: secret,
          artist: artist,
          track: track,
          timestamp: ts,
          album: album,
        ));
      }
    }
    if (settings.extra<bool>('listenbrainzScrobble', false)) {
      final token = settings.extra<String>('listenbrainzToken', '');
      if (token.isNotEmpty) {
        unawaited(GetIt.I<ScrobbleService>().submitListenBrainz(
          token: token,
          artist: artist,
          track: track,
          album: album,
          timestamp: ts,
          singleRelease: true,
        ));
      }
    }
  }

  /// Current track's normalization-adjusted playback gain (Windows-relevant:
  /// applied via just_audio's cross-platform `setVolume`, not the Android-only
  /// loudness enhancer).
  double get _dspTargetGain {
    final settings = GetIt.I<SettingsManager>();
    final id = _currentSongNotifier.value?.id;
    return DesktopDsp.forTrack(
      userVolume: _player.volume == 0 ? 1.0 : _player.volume,
      loudnessDb: id == null ? null : StreamResolver.instance.loudnessFor(id),
      normalizationOn: settings.loudnessEnabled,
      preset: settings.loudnessPreset,
      targetGainDb: settings.loudnessTargetGain,
    );
  }

  /// Apply replay-gain normalization immediately (no envelope).
  Future<void> _applyDspGain() async {
    await _player.setVolume(_dspTargetGain);
  }

  /// Fades the newly-started track in from silence using the crossfade
  /// duration/curve, ramping toward the DSP-adjusted target gain.
  Future<void> _applyTrackFadeIn() async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled) {
      await _applyDspGain();
      return;
    }
    final peak = _dspTargetGain;
    final ms = (settings.crossfadeDuration * 1000).round();
    if (ms <= 0) {
      await _player.setVolume(peak);
      return;
    }
    final steps = (ms / 40).ceil().clamp(1, 100);
    final stepDuration = Duration(milliseconds: (ms ~/ steps).clamp(1, 1000));
    for (var i = 0; i <= steps; i++) {
      if (!_player.playing) break;
      final t = i / steps;
      await _player.setVolume(peak * CrossfadeCurve.fadeIn(t));
      await Future<void>.delayed(stepDuration);
    }
    await _player.setVolume(peak);
  }

  Future<void> stop() async {
    // Persist the track that was playing so the next launch can resume it.
    await saveState();
    await _player.stop();
    await _player.clearAudioSources();
    await _player.seek(Duration.zero, index: 0);
    _currentIndex.value = null;
    _currentSongNotifier.value = null;
    notifyListeners();
  }

  Future<void> _addSongListToQueue(List songs, {bool isNext = false}) async {
    if (songs.isEmpty) return;

    // Convert your song objects into AudioSources
    final newSources = await Future.wait(songs.map((song) async {
      final mapSong = Map<String, dynamic>.from(song);
      return await _getAudioSource(mapSong);
    }));

    // Current queue length
    final queueLength = _player.sequence.length;

    if (isNext) {
      // Insert immediately after the current index
      final currentIndex = _player.currentIndex ?? -1;
      int insertIndex = (currentIndex + 1).clamp(0, queueLength);
      await _player.insertAudioSources(insertIndex, newSources);
    } else {
      // Append to the end
      await _player.addAudioSources(newSources);
    }
  }

  void _listenToAutofetch() {
    player.currentIndexStream.listen((index) async {
      if (index == null) return;
      if (player.sequence.length - index < 5 &&
          GetIt.I<SettingsManager>().autofetchSongs &&
          autoFetching == false) {
        autoFetching = true;
        List nextSongs = await GetIt.I<YTMusic>()
            .getNextSongList(videoId: player.sequence[index].tag.id);
        if (nextSongs.isNotEmpty) nextSongs.removeAt(0);
        await _addSongListToQueue(nextSongs);
        autoFetching = false;
      }
    });
  }

  void setTimer(Duration duration) {
    sleepTimer.start(duration);
    notifyListeners();
  }

  /// Ports the Android "pause when the current song ends" option.
  void setEndOfTrackTimer() {
    sleepTimer.startEndOfTrack();
    notifyListeners();
  }

  void cancelTimer() {
    sleepTimer.clear();
    notifyListeners();
  }

  /// Android `varispeed`: link pitch to playback speed (tape-style effects)
  /// or keep pitch constant. Backed by just_audio's cross-platform DSP.
  Future<void> setPlaybackSpeed(double speed, {bool preservePitch = true}) async {
    final s = speed.clamp(0.5, 2.0);
    await _player.setSpeed(s);
    try {
      await _player.setPitch(preservePitch ? 1.0 : s);
    } catch (_) {
      // Pitch shifting is not supported on every platform.
    }
  }

  /// Android `seek_seconds_addup`: each skip adds 5 extra seconds
  /// incrementally (only when the setting is enabled).
  Duration seekStep(Duration base, {required bool progressive}) =>
      progressive ? base + const Duration(seconds: 5) : base;
}

class _JustAudioSleepTarget implements SleepTimerTarget {
  _JustAudioSleepTarget(this._player);

  final AudioPlayer _player;

  @override
  double get volume => _player.volume;

  @override
  set volume(double value) {
    unawaited(_player.setVolume(value));
  }

  @override
  Future<void> pause() => _player.pause();
}

enum ButtonState { loading, paused, playing }

enum LoopState { off, all, one }

class ProgressBarState {
  Duration current;
  Duration buffered;
  Duration total;
  ProgressBarState(
      {this.current = Duration.zero,
      this.buffered = Duration.zero,
      this.total = Duration.zero});
}
