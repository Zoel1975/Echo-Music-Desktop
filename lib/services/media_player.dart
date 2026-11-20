import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Echo/services/crossfade_engine.dart';
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
        // Phase 1 remainder: surface the failure to the UI instead of failing
        // silently into "paused".
        playbackError.value = 'Playback error: ${e.toString()}';
        _buttonState.value = ButtonState.paused;
        notifyListeners();
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

  Future<AudioSource> _getAudioSource(Map<String, dynamic> song) async {
    MediaItem tag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: Uri.parse(
          song['thumbnails']?.first['url'].replaceAll('w60-h60', 'w225-h225')),
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );

    final bool isDownloaded = song['status'] == 'DOWNLOADED' &&
        song['path'] != null &&
        (await File(song['path']).exists());

    if (isDownloaded) {
      return AudioSource.file(song['path'], tag: tag);
    } else {
      // Data Saver forces the low-bitrate stream (Android's Wi-Fi/Cellular
      // quality ceiling, adapted for desktop).
      final settings = GetIt.I<SettingsManager>();
      final quality = settings.dataSaver
          ? 'low'
          : settings.streamingQuality.name.toLowerCase();
      // Use direct URL approach for macOS for better compatibility with AVFoundation
      if (Platform.isMacOS) {
        return await getDirectUrlAudioSource(song['videoId'], quality, tag);
      }
      return YouTubeAudioSource(
        videoId: song['videoId'],
        quality: quality,
        tag: tag,
      );
    }
  }

  int _lastPlayRequestId = 0;

  Future<void> playSong(Map<String, dynamic> song) async {
    if (song['videoId'] == null) return;

    // Generate a new request ID
    final int requestId = DateTime.now().millisecondsSinceEpoch;
    _lastPlayRequestId = requestId;

    // OPTIMISTIC UPDATE: Show miniplayer immediately with loading state
    MediaItem tempTag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: Uri.parse(
          song['thumbnails']?.first['url'].replaceAll('w60-h60', 'w225-h225')),
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );
    _currentSongNotifier.value = tempTag;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    // stop and set the tapped song as the single source so it plays immediately
    try {
      await _player.pause();
      await _player.stop();
      if (_lastPlayRequestId != requestId) return; // Stale request
      await _player.clearAudioSources();
      if (_lastPlayRequestId != requestId) return; // Stale request
    } catch (e) {
      // Ignore stop errors
    }

    try {
      final source = await _getAudioSource(song);
      if (_lastPlayRequestId != requestId)
        return; // Stale request, user clicked something else

      // Set audio source and play immediately (no need for separate load())
      await _player.setAudioSource(source);
      if (_lastPlayRequestId != requestId) return;

      // Play immediately - just_audio handles loading internally
      await _player.play();
      // Apply the real crossfade envelope: when crossfade is enabled the new
      // track fades in from silence over the configured duration (equal-power
      // curve), giving a smooth blend instead of an abrupt start.
      unawaited(_applyTrackFadeIn());
    } catch (e) {
      if (_lastPlayRequestId == requestId) {
        print("Error playing song: $e");
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
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

    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      await _player.stop();

      // Play just the selected song immediately - no waiting
      final selectedSong = Map<String, dynamic>.from(songs[index]);
      final firstSource = await _getAudioSource(selectedSong);

      await _player.setAudioSource(firstSource);
      // Don't wait for load - just play immediately
      _player.play(); // Don't await - let it start playing while we add more

      // Add rest of playlist completely in background (fire and forget)
      if (songs.length > 1) {
        // Use unawaited to truly run in background
        Future(() => _addRemainingToPlaylist(songs, index));
      }
    } catch (e) {
      print('Error in playAll: $e');
      _buttonState.value = ButtonState.paused;
      notifyListeners();
    }
  }

  // Lazy loading: only add next few songs, not entire playlist
  Future<void> _addRemainingToPlaylist(List songs, int playedIndex) async {
    try {
      // Only preload next 3 songs to avoid hammering YouTube API
      final int maxPreload = 3;
      int added = 0;

      // Add songs after the played index (next songs first)
      for (int i = playedIndex + 1;
          i < songs.length && added < maxPreload;
          i++) {
        try {
          final source =
              await _getAudioSource(Map<String, dynamic>.from(songs[i]));
          await _player.addAudioSource(source);
          added++;
        } catch (e) {
          // Skip failed songs silently
        }
      }
    } catch (e) {
      print('Error adding remaining songs: $e');
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

  /// Fades the newly-started track in from silence using the crossfade
  /// duration/curve. Called after `play()` when crossfade is enabled.
  Future<void> _applyTrackFadeIn() async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled) return;
    final ms = (settings.crossfadeDuration * 1000).round();
    if (ms <= 0) return;
    final steps = (ms / 40).ceil().clamp(1, 100);
    final stepDuration = Duration(milliseconds: (ms ~/ steps).clamp(1, 1000));
    for (var i = 0; i <= steps; i++) {
      if (!_player.playing) break;
      final t = i / steps;
      await _player.setVolume(CrossfadeCurve.fadeIn(t));
      await Future<void>.delayed(stepDuration);
    }
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
