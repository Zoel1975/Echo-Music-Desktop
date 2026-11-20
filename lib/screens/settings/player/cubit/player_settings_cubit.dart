import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../../../services/audio_device_service.dart';
import '../../../../../../services/media_player.dart';
import '../../../../../../services/remote_control_service.dart';
import '../../../../../../services/settings_manager.dart';
import '../../../../../../services/silence_filter.dart';

part 'player_settings_state.dart';

class PlayerSettingsCubit extends Cubit<PlayerSettingsState> {
  final SettingsManager _settings = GetIt.I<SettingsManager>();
  final MediaPlayer _player = GetIt.I<MediaPlayer>();
  final AudioDeviceService _devices = GetIt.I<AudioDeviceService>();
  final RemoteControlService _remote = GetIt.I<RemoteControlService>();

  late final VoidCallback _listener;

  PlayerSettingsCubit()
      : super(
          PlayerSettingsLoaded(
            skipSilence: GetIt.I<SettingsManager>().skipSilence,
            showSeekButtons: GetIt.I<SettingsManager>().showSeekButtons,
            crossfadeEnabled: GetIt.I<SettingsManager>().crossfadeEnabled,
            crossfadeDuration: GetIt.I<SettingsManager>().crossfadeDuration,
            dataSaver: GetIt.I<SettingsManager>().dataSaver,
            streamingQuality: GetIt.I<SettingsManager>().streamingQuality,
            audioNormalization: GetIt.I<SettingsManager>().loudnessEnabled,
            loudnessGain: GetIt.I<SettingsManager>().loudnessTargetGain,
            castEnabled: GetIt.I<SettingsManager>().castEnabled,
            remoteControlEnabled:
                GetIt.I<SettingsManager>().remoteControlEnabled,
            audioDeviceId: GetIt.I<SettingsManager>().audioDeviceId,
            remoteControlUrl: GetIt.I<RemoteControlService>().url,
            persistentQueue: GetIt.I<SettingsManager>().persistentQueue,
            autoLoadMore: GetIt.I<SettingsManager>().autoLoadMore,
            similarContent: GetIt.I<SettingsManager>().similarContent,
            autoSkipOnError: GetIt.I<SettingsManager>().autoSkipOnError,
            rememberShuffleRepeat:
                GetIt.I<SettingsManager>().rememberShuffleRepeat,
            preventDuplicates: GetIt.I<SettingsManager>().preventDuplicates,
            autoDownloadOnLike: GetIt.I<SettingsManager>().autoDownloadOnLike,
            progressiveSeek: GetIt.I<SettingsManager>().progressiveSeek,
            crossfadeGapless: GetIt.I<SettingsManager>().crossfadeGapless,
            historyDuration: GetIt.I<SettingsManager>().historyDuration,
            loudnessPreset: GetIt.I<SettingsManager>().loudnessPreset,
            preloadNext: GetIt.I<SettingsManager>().preloadNext,
            preloadLimit: GetIt.I<SettingsManager>().preloadLimit,
          ),
        ) {
    _listener = () {
      if (!isClosed) _emitState();
    };
    _settings.addListener(_listener);
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await _devices.listDevices();
    if (!isClosed) {
      emit((state as PlayerSettingsLoaded).copyWith(audioDevices: devices));
    }
  }

  Future<void> refreshDevices() => _loadDevices();

  void _emitState() {
    if (isClosed) return;
    final s = state as PlayerSettingsLoaded;
    emit(
      s.copyWith(
        skipSilence: _settings.skipSilence,
        showSeekButtons: _settings.showSeekButtons,
        crossfadeEnabled: _settings.crossfadeEnabled,
        crossfadeDuration: _settings.crossfadeDuration,
        dataSaver: _settings.dataSaver,
        streamingQuality: _settings.streamingQuality,
        audioNormalization: _settings.loudnessEnabled,
        loudnessGain: _settings.loudnessTargetGain,
        castEnabled: _settings.castEnabled,
        remoteControlEnabled: _settings.remoteControlEnabled,
        audioDeviceId: _settings.audioDeviceId,
        remoteControlUrl: _remote.url,
        persistentQueue: _settings.persistentQueue,
        autoLoadMore: _settings.autoLoadMore,
        similarContent: _settings.similarContent,
        autoSkipOnError: _settings.autoSkipOnError,
        rememberShuffleRepeat: _settings.rememberShuffleRepeat,
        preventDuplicates: _settings.preventDuplicates,
        autoDownloadOnLike: _settings.autoDownloadOnLike,
        progressiveSeek: _settings.progressiveSeek,
        crossfadeGapless: _settings.crossfadeGapless,
        historyDuration: _settings.historyDuration,
        loudnessPreset: _settings.loudnessPreset,
        preloadNext: _settings.preloadNext,
        preloadLimit: _settings.preloadLimit,
      ),
    );
  }

  Future<void> setSkipSilence(bool value) async {
    await _player.skipSilence(value);
    // Desktop: update the mpv filter chain. mpv snapshots `af` at player
    // creation, so apply it and reload the current source to take effect.
    SilenceFilter.apply(enabled: value);
    await _player.reloadCurrentSource();
  }

  void setShowSeekButtons(bool value) => _settings.showSeekButtons = value;

  void setCrossfadeEnabled(bool value) => _settings.crossfadeEnabled = value;

  void setCrossfadeDuration(double value) =>
      _settings.crossfadeDuration = value;

  void setDataSaver(bool value) => _settings.dataSaver = value;

  void setStreamingQuality(dynamic value) => _settings.streamingQuality = value;

  Future<void> setAudioNormalization(bool value) async {
    await _player.setLoudnessEnabled(value);
  }

  Future<void> setLoudnessGain(double value) async {
    await _player.setLoudnessTargetGain(value);
  }

  Future<void> setCastEnabled(bool value) async {
    // Cast on desktop = expose a real, LAN-discoverable playback endpoint that
    // other devices can open and drive (the desktop counterpart of Google Cast).
    if (value) {
      await _remote.start();
    } else if (!_settings.remoteControlEnabled) {
      // Only stop when the separate LAN-remote toggle is also off.
      await _remote.stop();
    }
    _settings.castEnabled = value;
    _emitState();
  }

  Future<void> setRemoteControlEnabled(bool value) async {
    if (value) {
      await _remote.start();
    } else {
      await _remote.stop();
    }
    _settings.remoteControlEnabled = value;
    _emitState();
  }

  Future<void> setAudioDevice(String id) async {
    await _devices.selectDevice(id);
    _settings.audioDeviceId = id;
    _emitState();
  }

  void setPersistentQueue(bool v) => _settings.persistentQueue = v;
  void setAutoLoadMore(bool v) => _settings.autoLoadMore = v;
  void setSimilarContent(bool v) => _settings.similarContent = v;
  void setAutoSkipOnError(bool v) => _settings.autoSkipOnError = v;
  void setRememberShuffleRepeat(bool v) => _settings.rememberShuffleRepeat = v;
  void setPreventDuplicates(bool v) => _settings.preventDuplicates = v;
  void setAutoDownloadOnLike(bool v) => _settings.autoDownloadOnLike = v;
  void setProgressiveSeek(bool v) => _settings.progressiveSeek = v;
  void setCrossfadeGapless(bool v) => _settings.crossfadeGapless = v;
  void setHistoryDuration(double v) => _settings.historyDuration = v;
  void setLoudnessPreset(String v) => _settings.loudnessPreset = v;
  void setPreloadNext(bool v) => _settings.preloadNext = v;
  void setPreloadLimit(double v) => _settings.preloadLimit = v;

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
