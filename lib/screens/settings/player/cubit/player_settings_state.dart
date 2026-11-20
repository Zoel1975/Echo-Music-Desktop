part of 'player_settings_cubit.dart';

@immutable
sealed class PlayerSettingsState {
  const PlayerSettingsState();
}

class PlayerSettingsLoaded extends PlayerSettingsState {
  final bool skipSilence;
  final bool showSeekButtons;
  final bool crossfadeEnabled;
  final double crossfadeDuration;
  final bool dataSaver;
  final dynamic streamingQuality;
  final bool audioNormalization;
  final double loudnessGain;
  final bool castEnabled;
  final bool remoteControlEnabled;
  final String audioDeviceId;
  final List<AudioDeviceEntry> audioDevices;
  final String? remoteControlUrl;

  const PlayerSettingsLoaded({
    required this.skipSilence,
    required this.showSeekButtons,
    required this.crossfadeEnabled,
    required this.crossfadeDuration,
    required this.dataSaver,
    required this.streamingQuality,
    required this.audioNormalization,
    required this.loudnessGain,
    required this.castEnabled,
    required this.remoteControlEnabled,
    required this.audioDeviceId,
    this.audioDevices = const [],
    this.remoteControlUrl,
  });

  PlayerSettingsLoaded copyWith({
    bool? skipSilence,
    bool? showSeekButtons,
    bool? crossfadeEnabled,
    double? crossfadeDuration,
    bool? dataSaver,
    dynamic streamingQuality,
    bool? audioNormalization,
    double? loudnessGain,
    bool? castEnabled,
    bool? remoteControlEnabled,
    String? audioDeviceId,
    List<AudioDeviceEntry>? audioDevices,
    String? remoteControlUrl,
  }) {
    return PlayerSettingsLoaded(
      skipSilence: skipSilence ?? this.skipSilence,
      showSeekButtons: showSeekButtons ?? this.showSeekButtons,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaver: dataSaver ?? this.dataSaver,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      audioNormalization: audioNormalization ?? this.audioNormalization,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      castEnabled: castEnabled ?? this.castEnabled,
      remoteControlEnabled: remoteControlEnabled ?? this.remoteControlEnabled,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      audioDevices: audioDevices ?? this.audioDevices,
      remoteControlUrl: remoteControlUrl ?? this.remoteControlUrl,
    );
  }
}
