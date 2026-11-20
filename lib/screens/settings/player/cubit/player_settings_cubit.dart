import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../../../services/audio_device_service.dart';
import '../../../../../../services/media_player.dart';
import '../../../../../../services/remote_control_service.dart';
import '../../../../../../services/settings_manager.dart';

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
      ),
    );
  }

  Future<void> setSkipSilence(bool value) async {
    await _player.skipSilence(value);
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

  void setCastEnabled(bool value) => _settings.castEnabled = value;

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

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
