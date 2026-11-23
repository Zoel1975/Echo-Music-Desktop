import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Echo/services/audio_source_info.dart';
import 'package:Echo/services/automix_debug.dart';
import 'package:Echo/services/beat_analysis.dart';
import 'package:Echo/services/beat_analyzer_service.dart';
import 'package:Echo/services/crossfade_engine.dart';
import 'package:Echo/services/crossfade_prearm.dart';
import 'package:Echo/services/desktop_dsp.dart';
import 'package:Echo/services/eq_settings.dart';
import 'package:Echo/services/harmonic_mixing.dart';
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

  /// Invalidates stale fade-in loops when a new play request arrives.
  int _fadeInGeneration = 0;

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

  /// Reflects just_audio's shuffle state for the player UI.
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);

  Future<void> setShuffleModeEnabled(bool value) =>
      _player.setShuffleModeEnabled(value);
  ValueNotifier<LoopMode> get loopMode => _loopMode;
  ValueNotifier<Duration?> get timerDuration => sleepTimer.remaining;

  /// Read-only instrumentation for the diagnostic probe: volumes during a
  /// handoff/crossfade must change gradually, never jump in one step.
  BeatAnalysisResult? _beat;
  BeatAnalysisResult? _nextBeat;
  String? _beatAnalysisId;
  BeatAnalysisResult? get diagnosticBeat => _beat;
  BeatAnalysisResult? get diagnosticNextBeat => _nextBeat;

  double get diagnosticOutVolume => _xfadeOutPlayer?.volume ?? 0;
  bool get diagnosticHandoffRunning => _handoffEngine?.isRunning ?? false;
  bool get diagnosticCrossfading => _xfade?.isCrossfading ?? false;

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
      if (GetIt.I<SettingsManager>().persistentQueue) unawaited(saveState());
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
        if (GetIt.I<SettingsManager>().persistentQueue) unawaited(saveState());
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
  CrossfadeEngine? _handoffEngine;
  final AdaptivePreArmManager _preArm = AdaptivePreArmManager();
  bool _xfadeArmed = false;
  int? _xfadeArmedIndex;
  bool _xfadeTriggered = false;
  bool _xfadePreparing = false;
  int _crossfadeGeneration = 0;
  int? _tooLateLoggedIndex;

  /// Short equal-power ramp used before the crossfade itself: the outgoing
  /// player starts muted, so jumping straight to full volume would click.
  static const Duration handoffRampDuration = Duration(milliseconds: 220);

  /// A freshly attached StreamAudioSource needs a moment to buffer the range
  /// at [position]. Starting the handoff before that produced an audible
  /// freeze: the outgoing player went silent exactly when it became audible.
  Future<bool> _waitForOutgoingReady(
    AudioPlayer outgoing,
    Duration position,
  ) async {
    const maxWait = Duration(milliseconds: 2500);
    final started = DateTime.now();
    var lastBuffered = Duration.zero;
    while (DateTime.now().difference(started) < maxWait) {
      final buffered = outgoing.bufferedPosition;
      lastBuffered = buffered;
      if (outgoing.playing &&
          buffered >= position + const Duration(milliseconds: 150)) {
        return true;
      }
      // media_kit does not always expose bufferedPosition for a fresh
      // StreamAudioSource. If the player is running, proceed instead of
      // silently aborting every crossfade.
      if (outgoing.playing &&
          DateTime.now().difference(started) >= const Duration(milliseconds: 1200)) {
        AutomixDebug.instance.log(
          'standby playing, buffered=${lastBuffered.inMilliseconds}ms '
          '(richiesto ${position.inMilliseconds}ms) → procedo comunque',
          level: 'WARN',
        );
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    // media_kit may never report bufferedPosition for a freshly seeked
    // StreamAudioSource. Don't abort the whole crossfade: proceed and retry
    // play() at the trigger instant (the source is already attached).
    AutomixDebug.instance.log(
      'standby buffered non disponibile: playing=${outgoing.playing} '
      'buffered=${lastBuffered.inMilliseconds}ms → procedo',
      level: 'WARN',
    );
    return true;
  }

  Future<void> _rampHandoff(
    FadeablePlayer from,
    FadeablePlayer to,
    double peak,
  ) async {
    _handoffEngine?.cancel();
    AutomixDebug.instance
        .set(handoffRunning: true, status: 'HANDOFF');
    AutomixDebug.instance.log('handoff start peak=${peak.toStringAsFixed(2)}');
    if (peak <= 0.001) {
      await from.setVolume(0);
      await to.setVolume(0);
      return;
    }
    final engine = CrossfadeEngine(
      out: from,
      inPlayer: to,
      tick: const Duration(milliseconds: 25),
    )..peakVolume = peak;
    _handoffEngine = engine;
    final done = Completer<void>();
    await engine.start(handoffRampDuration, onDone: () {
      if (!done.isCompleted) done.complete();
    });
    // A lost platform callback must not hang the play request.
    var completed = true;
    await done.future.timeout(
      const Duration(milliseconds: 700),
      onTimeout: () => completed = false,
    );
    engine.dispose();
    if (identical(_handoffEngine, engine)) _handoffEngine = null;
    if (!completed) {
      // Force the end state: the main player must be silent before it seeks
      // to the next track, otherwise that seek is audible as a "scattino".
      await Future.wait([from.setVolume(0), to.setVolume(peak)]);
      AutomixDebug.instance.log('handoff timeout: volumi forzati', level: 'WARN');
    }
    AutomixDebug.instance.set(handoffRunning: false);
    AutomixDebug.instance.log('handoff fine');
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
      _maybeSkipSponsor(position);
      _maybePreArmQueueCrossfade(position);
    });
  }

  /// Automatic queue advance: when the current track is within the crossfade
  /// window of its end and a next track is queued, overlap them using a
  /// dedicated outgoing player + equal-power ramp instead of a hard cut.
  /// Cancels an in-progress pre-arm (user seeked, paused or picked a song).
  Future<void> _cancelCrossfadePreArm() async {
    _xfade?.cancel();
    _handoffEngine?.cancel();
    _xfadeArmed = false;
    _xfadeArmedIndex = null;
    _xfadeTriggered = false;
    final out = _xfadeOutPlayer;
    if (out != null) {
      await out.pause();
      await out.setVolume(0);
    }
  }

  /// Creates the outgoing player with a temporary low-shelf duck filter: mpv
  /// snapshots `af` at player construction, so the duck applies only to this
  /// player while the main player keeps the normal EQ chain.
  Future<AudioPlayer> _createDuckedOutPlayer() async {
    final settings = GetIt.I<SettingsManager>();
    final old = _xfadeOutPlayer;
    EqSettings.apply(settings, duckOutgoing: true);
    final player = AudioPlayer();
    EqSettings.apply(settings); // restore before any other player is created
    _xfadeOutPlayer = player;
    if (old != null && old != player) {
      try {
        await old.pause();
        await old.dispose();
      } catch (_) {}
    }
    return player;
  }

  /// DJ blend length: 16 beats of the outgoing track when Automix is active.
  Duration _automixDuration(SettingsManager settings) {
    if (settings.automixBeatAlign && _beat != null) {
      return Duration(milliseconds: djBlendDurationMs(_beat!));
    }
    return Duration(milliseconds: (settings.crossfadeDuration * 1000).round());
  }

  /// Uses the detected musical key (Camelot wheel) to pick the most harmonically
  /// compatible of the next few queued tracks, then moves it right after the
  /// current one. Returns the (possibly changed) next index.
  Future<int> _applyHarmonicMix(int idx, int nextIdx) async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled ||
        !settings.automixBeatAlign ||
        !settings.automixHarmonicMix ||
        _beat == null ||
        camelotFor(_beat!) == null) {
      return nextIdx;
    }
    final fromKey = camelotFor(_beat!);
    const maxCandidates = 3;
    final end = math.min(_songList.length, nextIdx + maxCandidates);
    final candidates = <int>[];
    for (var i = nextIdx; i < end; i++) {
      candidates.add(i);
    }
    if (candidates.length < 2) {
      AutomixDebug.instance.set(
        harmonicChoice: 'unico candidato (${fromKey?.code})',
        harmonicScore: harmonicScore(
          fromKey,
          _nextBeat == null ? null : camelotFor(_nextBeat!),
        ),
      );
      return nextIdx;
    }

    // Analyze candidates during the pre-arm lead (results are cached in Hive).
    final keys = <int, CamelotKey?>{};
    final beats = <int, BeatAnalysisResult?>{};
    for (final i in candidates) {
      final tag = _songList[i].tag;
      if (tag is! MediaItem) continue;
      final cached = BeatAnalyzerService.cached(tag.id);
      // Bound the analysis: it must finish inside the pre-arm lead, otherwise
      // the transition trigger arrives while we are still decoding.
      final beat = cached ??
          await BeatAnalyzerService.analyzeSong(
            Map<String, dynamic>.from(tag.extras ?? const <String, dynamic>{}),
          ).timeout(const Duration(seconds: 3), onTimeout: () => null);
      beats[i] = beat;
      keys[i] = beat == null ? null : camelotFor(beat);
    }

    final chosen = pickHarmonicNext(
      nextIndex: nextIdx,
      candidateIndices: candidates,
      from: fromKey,
      keys: keys,
    );
    final score = harmonicScore(fromKey, keys[chosen]);
    AutomixDebug.instance.set(
      harmonicChoice: '${fromKey?.code} → ${keys[chosen]?.code ?? '?'} '
          '(#$chosen · ${keys[chosen]?.code ?? '?'})',
      harmonicScore: score,
    );
    AutomixDebug.instance.log(
      'mixing armonico: ${fromKey?.code} → scelto #$chosen '
      '${keys[chosen]?.code ?? '?'} score=${score.toStringAsFixed(2)} '
      '(candidati: ${candidates.map((i) => '#$i ${keys[i]?.code ?? '?'}').join(', ')})',
    );

    if (chosen != nextIdx) {
      try {
        await _player.moveAudioSource(chosen, nextIdx);
        AutomixDebug.instance.log('coda riordinata: #$chosen → #$nextIdx');
      } catch (e) {
        AutomixDebug.instance.log('riordino coda fallito: $e', level: 'WARN');
      }
    }
    final chosenBeat = beats[chosen];
    if (chosenBeat != null) {
      _nextBeat = chosenBeat;
      AutomixDebug.instance.set(inBeat: chosenBeat);
    }
    return nextIdx;
  }

  /// Port of Android `StandbyCrossfadeScheduler`: prepare the standby player
  /// early and wait until it is really ready (STATE_READY equivalent) instead
  /// of assuming a freshly created source can start instantly.
  Future<bool> _prepareStandby(Duration position, int idx) async {
    final started = DateTime.now();
    try {
      final currentTag = _songList[idx].tag;
      if (currentTag is! MediaItem) return false;
      await _cancelCrossfadePreArm();
      final outPlayer = await _createDuckedOutPlayer();
      _xfade = QueueCrossfadeController(
        makePlayer: () => AudioPlayerAdapter(outPlayer),
      );
      final outSource = await _getAudioSource(currentTag.extras ?? {});
      await outPlayer.setAudioSource(outSource);
      await outPlayer.seek(position);
      await outPlayer.setVolume(0);
      await outPlayer.play();
      AutomixDebug.instance.log(
        'standby avviato: playing=${outPlayer.playing} '
        'buffered=${outPlayer.bufferedPosition.inMilliseconds}ms '
        'pos=${outPlayer.position.inMilliseconds}ms seek=${position.inMilliseconds}ms',
      );
      final ready = await _waitForOutgoingReady(outPlayer, position);
      // Android's AdaptivePreArmManager uses this to expand/decay the lead.
      _preArm.recordPreparationDuration(DateTime.now().difference(started));
      return ready;
    } catch (e) {
      debugPrint('Crossfade pre-arm failed: $e');
      return false;
    }
  }

  Future<void> _triggerQueueCrossfade(
    int idx,
    int nextIdx,
    Duration position,
  ) async {
    if (_xfadeTriggered) return;
    _xfadeTriggered = true;
    final outPlayer = _xfadeOutPlayer;
    final nextTag = _songList[nextIdx].tag;
    if (outPlayer == null || !_xfadeArmed || nextTag is! MediaItem) {
      AutomixDebug.instance.log(
        'trigger annullato: out=${outPlayer != null} armed=$_xfadeArmed '
        'nextTag=${nextTag.runtimeType}',
        level: 'ERROR',
      );
      _xfadeTriggered = false;
      return;
    }
    final peak = _dspTargetGain; // captured before the main player is muted
    final settings = GetIt.I<SettingsManager>();
    try {
      // Some media_kit sources only start after the trigger seek; retry here
      // so the outgoing track is audible when the handoff begins.
      if (!outPlayer.playing) {
        await outPlayer.play();
        AutomixDebug.instance.log(
          'standby riavviato al trigger: playing=${outPlayer.playing}',
        );
      }
      await _rampHandoff(
        AudioPlayerAdapter(_player),
        AudioPlayerAdapter(outPlayer),
        peak,
      );
      // Phase 2: enter the incoming track at the offset whose beat grid lines
      // up with the fade end, instead of always starting at 0:00.
      final blendMs = _automixDuration(settings).inMilliseconds;
      var startMs = 0;
      if (settings.automixBeatAlign && _nextBeat != null) {
        startMs = beatAlignedStartMs(_nextBeat!, blendMs);
      }
      AutomixDebug.instance.set(
        status: 'FADING',
        fading: true,
        blendMs: blendMs,
        incomingStartMs: startMs,
        tempoRatio: (_beat != null && _nextBeat != null)
            ? _nextBeat!.bpm / _beat!.bpm
            : null,
        inBeat: _nextBeat,
      );
      AutomixDebug.instance.log(
        'CROSSFADE AVVIATO: blend=${blendMs}ms peak=${peak.toStringAsFixed(2)} '
        'incomingStart=${startMs}ms inBpm=${_nextBeat?.bpm.toStringAsFixed(1) ?? '?'}',
      );
      await _player.seek(Duration(milliseconds: startMs), index: nextIdx);
      _currentSongNotifier.value = nextTag;
      _currentIndex.value = nextIdx;
      await _player.play();

      await _xfade!.start(
        incoming: AudioPlayerAdapter(_player),
        duration: Duration(milliseconds: blendMs),
        peakVolume: peak,
        startOutgoing: (_) async {},
        onDone: () {
          outPlayer.pause();
          _player.setVolume(peak);
          _xfadeArmed = false;
          _xfadeArmedIndex = null;
          _xfadeTriggered = false;
          AutomixDebug.instance.set(
            status: 'IDLE',
            fading: false,
            handoffRunning: false,
          );
          AutomixDebug.instance.log('crossfade completato');
        },
      );
    } catch (e) {
      AutomixDebug.instance.log('crossfade ERROR: $e', level: 'ERROR');
      AutomixDebug.instance.set(status: 'ERROR', lastError: e.toString());
      debugPrint('Queue-end crossfade failed: $e');
      _xfade?.cancel();
      _xfadeArmed = false;
      _xfadeArmedIndex = null;
      _xfadeTriggered = false;
    }
  }

  /// Android Echo arms the standby player with a 20s (up to 35s adaptive)
  /// lead, then starts the blend only once the remaining time equals the
  /// crossfade duration. Preparing inside the fade window caused the stall.
  Future<void> _maybePreArmQueueCrossfade(Duration position) async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled) {
      if (AutomixDebug.instance.crossfadeEnabled) {
        AutomixDebug.instance.log('crossfade disabilitato', level: 'WARN');
      }
      AutomixDebug.instance.set(crossfadeEnabled: false, status: 'IDLE');
      return;
    }
    final idx = _player.currentIndex;
    if (idx == null) return;
    final nextIdx = idx + 1;
    if (nextIdx >= _songList.length) return;
    final duration = _player.duration;
    if (duration == null) return;
    final crossfade = _automixDuration(settings);
    if (duration <= crossfade) return;

    final remaining = duration - position;
    var triggerMs = crossfade.inMilliseconds;
    if (settings.automixBeatAlign && _beat != null) {
      triggerMs = automixTriggerMs(
        duration.inMilliseconds,
        crossfade.inMilliseconds,
        _beat!,
        mixOutMs: _beat!.mixOutMs,
      );
    }
    final baseLead = _preArm.currentLeadTime;
    // Automix can move the trigger earlier than the adaptive lead (e.g. a
    // mix-out near 199s of a 213s track). The standby must be prepared before
    // the trigger, otherwise crossfade can never start.
    final triggerDuration = Duration(milliseconds: triggerMs);
    final lead = baseLead > triggerDuration + const Duration(milliseconds: 12000)
        ? baseLead
        : triggerDuration + const Duration(milliseconds: 12000);
    AutomixDebug.instance.set(
      status: _xfadeTriggered
          ? 'FADING'
          : (_xfadeArmed && _xfadeArmedIndex == idx ? 'ARMED' : 'MONITOR'),
      leadMs: lead.inMilliseconds,
      blendMs: crossfade.inMilliseconds,
      triggerTimeMs: duration.inMilliseconds - triggerMs,
      outBeat: _beat,
      inBeat: _nextBeat,
      mainVolume: _player.volume,
      outVolume: _xfadeOutPlayer?.volume ?? 0,
    );
    final prepared = _xfadeArmed && _xfadeArmedIndex == idx;
    if (_xfadePreparing) return;
    if (!prepared) {
      final cutoffArm = PlaybackCutoffGuard.shouldPreArm(
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        bufferedMs: _player.bufferedPosition.inMilliseconds,
        baseLeadMs: lead.inMilliseconds,
      );
      if (remaining > lead && !cutoffArm) return;
      // Too late to prepare a standby: better a clean cut than a frozen fade.
      if (remaining.inMilliseconds <= triggerMs) {
        if (_tooLateLoggedIndex != idx) {
          AutomixDebug.instance.log(
            'pre-arm troppo tardivo (remaining=${remaining.inMilliseconds}ms '
            'trigger=$triggerMs) → nessun crossfade',
            level: 'WARN',
          );
          _tooLateLoggedIndex = idx;
        }
        return;
      }
      AutomixDebug.instance.log(
        'pre-arm idx=$idx remaining=${remaining.inMilliseconds}ms '
        'lead=${lead.inMilliseconds}ms blend=${crossfade.inMilliseconds}ms '
        'outBpm=${_beat?.bpm.toStringAsFixed(1) ?? '?'}',
      );
      final generation = ++_crossfadeGeneration;
      _xfadePreparing = true;
      final ready = await _prepareStandby(position, idx);
      if (!ready || generation != _crossfadeGeneration) {
        _xfadePreparing = false;
        if (!ready) {
          AutomixDebug.instance.log('pre-arm FALLITO (standby non pronto)',
              level: 'WARN');
        }
        return;
      }
      // Mark armed immediately: the position stream ticks every ~40 ms and
      // would otherwise restart the standby for every tick while the harmonic
      // analysis is running.
      _xfadeArmed = true;
      _xfadeArmedIndex = idx;
      await _applyHarmonicMix(idx, nextIdx);
      if (generation != _crossfadeGeneration) {
        _xfadePreparing = false;
        return;
      }
      _maybeAnalyzeNextBeat(nextIdx);
      _xfadePreparing = false;
    }
    if (remaining.inMilliseconds <= triggerMs &&
        idx + 1 < _songList.length) {
      await _triggerQueueCrossfade(idx, nextIdx, position);
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
      shuffleNotifier.value = data;
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
        if (GetIt.I<SettingsManager>().persistentQueue) unawaited(saveState());
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
  /// Lazily analyzes the current track's beat grid (Automix phase 1).
  void _maybeAnalyzeBeat() {
    final extras = _currentSongNotifier.value?.extras;
    final id = _currentSongNotifier.value?.id;
    if (extras == null || id == null) {
      _beat = null;
      _beatAnalysisId = null;
      return;
    }
    // The current-song notifier fires from several places (queue listener,
    // crossfade, restore). Analyze each track at most once.
    if (_beatAnalysisId == id) return;
    _beatAnalysisId = id;
    if (!GetIt.I.isRegistered<SettingsManager>()) return;
    final settings = GetIt.I<SettingsManager>();
    if (!settings.crossfadeEnabled || !settings.automixBeatAlign) {
      _beat = null;
      _nextBeat = null;
      return;
    }
    _nextBeat = null;
    _beat = BeatAnalyzerService.cached(id);
    if (_beat != null) return;
    // Don't compete with the first seconds of playback buffering: the beat
    // grid is only needed near the end of the track, 20 s before the fade.
    unawaited(Future<void>.delayed(const Duration(seconds: 2))
        .then((_) => BeatAnalyzerService.analyzeSong(
            Map<String, dynamic>.from(extras)))
        .then((result) {
      if (result == null) {
        AutomixDebug.instance.log('analisi OUT non riuscita', level: 'WARN');
        return;
      }
      if (_currentSongNotifier.value?.id == id) {
        _beat = result;
        AutomixDebug.instance.set(outBeat: result);
        AutomixDebug.instance.log(
          'analisi OUT: bpm=${result.bpm.toStringAsFixed(1)} '
          'key=${result.keyLabel ?? '?'} conf=${result.confidence.toStringAsFixed(2)} '
          'mixIn=${result.mixInMs} mixOut=${result.mixOutMs}',
        );
      }
    }));
  }

  /// Phase 2: analyze the queued track while the standby is being prepared so
  /// both beat grids are known before the blend starts.
  void _maybeAnalyzeNextBeat(int nextIdx) {
    if (nextIdx < 0 || nextIdx >= _songList.length) return;
    final tag = _songList[nextIdx].tag;
    if (tag is! MediaItem) return;
    if (!GetIt.I.isRegistered<SettingsManager>()) return;
    if (!GetIt.I<SettingsManager>().automixBeatAlign) return;
    final id = tag.id;
    _nextBeat = BeatAnalyzerService.cached(id);
    if (_nextBeat != null) return;
    unawaited(BeatAnalyzerService.analyzeSong(Map<String, dynamic>.from(
      tag.extras ?? const <String, dynamic>{},
    )).then((result) {
      if (result == null) {
        AutomixDebug.instance.log('analisi IN non riuscita', level: 'WARN');
        return;
      }
      if (_player.currentIndex == nextIdx - 1) {
        _nextBeat = result;
        AutomixDebug.instance.set(inBeat: result);
        AutomixDebug.instance.log(
          'analisi IN: bpm=${result.bpm.toStringAsFixed(1)} '
          'key=${result.keyLabel ?? '?'} mixIn=${result.mixInMs}',
        );
      }
    }));
  }

  void _syncSourceInfoFromCurrent() {
    final extras = _currentSongNotifier.value?.extras;
    if (extras == null) {
      playbackSource.value = null;
      _beat = null;
      return;
    }
    _maybeAnalyzeBeat();
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
    // A user-initiated switch invalidates any standby prepared by the queue.
    _crossfadeGeneration++;
    await _cancelCrossfadePreArm();

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
    AutomixDebug.instance.set(
      crossfadeEnabled: settings.crossfadeEnabled,
      automixEnabled: settings.automixBeatAlign,
      mainVolume: _player.volume,
    );
    AutomixDebug.instance.log(
      'play ${song['videoId']}: wasPlaying=$wasPlaying '
      'crossfade=${decision.enabled} peak=${decision.peakVolume.toStringAsFixed(2)}',
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
          duration: _automixDuration(settings),
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
    _handoffEngine?.cancel();
    AutomixDebug.instance.log(
      'crossfade utente: ${previousPosition.inMilliseconds}ms → '
      '${duration.inMilliseconds}ms peak=${peakVolume.toStringAsFixed(2)}',
    );
    final outPlayer = await _createDuckedOutPlayer();
    _xfade = QueueCrossfadeController(
      makePlayer: () => AudioPlayerAdapter(outPlayer),
    );

    // Prepare the outgoing track FIRST while the main player is still
    // audible. Previously the main player was stopped before this await, so
    // a network resolve left a silence gap followed by a click on restart.
    final outSource = await _getAudioSource(previousSong);
    if (_lastPlayRequestId != requestId) return;
    await outPlayer.setAudioSource(outSource);
    await outPlayer.seek(previousPosition);
    await outPlayer.setVolume(0);
    await outPlayer.play(); // decoded and running, but still silent
    if (_lastPlayRequestId != requestId) return;

    // Ramp from the still-audible main player to the muted outgoing player.
    // Setting the outgoing volume from 0 straight to peak was the audible
    // click right when the crossfade began.
    await _rampHandoff(
      AudioPlayerAdapter(_player),
      AudioPlayerAdapter(outPlayer),
      peakVolume,
    );
    if (_lastPlayRequestId != requestId) return;

    // Now it is safe to stop/replace the main source (already silent).
    await _player.pause();
    await _player.stop();
    await _player.clearAudioSources();
    if (_lastPlayRequestId != requestId) return;
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
        outPlayer.pause();
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
    if (GetIt.I<SettingsManager>().persistentQueue) await saveState();
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
        try {
          if (index >= player.sequence.length) return;
          List nextSongs = await GetIt.I<YTMusic>()
              .getNextSongList(videoId: player.sequence[index].tag.id);
          if (nextSongs.isNotEmpty) nextSongs.removeAt(0);
          await _addSongListToQueue(nextSongs);
        } catch (e) {
          debugPrint('autofetch failed: $e');
        } finally {
          autoFetching = false;
        }
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
