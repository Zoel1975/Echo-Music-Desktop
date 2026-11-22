part of 'player_settings_cubit.dart';

@immutable
sealed class PlayerSettingsState {
  const PlayerSettingsState();
}

class PlayerSettingsLoaded extends PlayerSettingsState {
  final bool skipSilence;
  final bool showSeekButtons;
  final bool crossfadeEnabled;
  final bool automixBeatAlign;
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

  // Android PlayerSettings.kt — Queue / Misc settings.
  final bool persistentQueue;
  final bool autoLoadMore;
  final bool similarContent;
  final bool autoSkipOnError;
  final bool rememberShuffleRepeat;
  final bool preventDuplicates;
  final bool autoDownloadOnLike;
  final bool progressiveSeek;
  final bool crossfadeGapless;
  final double historyDuration;
  final String loudnessPreset;
  final bool preloadNext;
  final double preloadLimit;

  const PlayerSettingsLoaded({
    required this.skipSilence,
    required this.showSeekButtons,
    required this.crossfadeEnabled,
    this.automixBeatAlign = true,
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
    this.persistentQueue = true,
    this.autoLoadMore = true,
    this.similarContent = true,
    this.autoSkipOnError = false,
    this.rememberShuffleRepeat = true,
    this.preventDuplicates = false,
    this.autoDownloadOnLike = false,
    this.progressiveSeek = false,
    this.crossfadeGapless = true,
    this.historyDuration = 1.0,
    this.loudnessPreset = 'Normal',
    this.preloadNext = true,
    this.preloadLimit = 10.0,
  });

  PlayerSettingsLoaded copyWith({
    bool? skipSilence,
    bool? showSeekButtons,
    bool? crossfadeEnabled,
    bool? automixBeatAlign,
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
    bool? persistentQueue,
    bool? autoLoadMore,
    bool? similarContent,
    bool? autoSkipOnError,
    bool? rememberShuffleRepeat,
    bool? preventDuplicates,
    bool? autoDownloadOnLike,
    bool? progressiveSeek,
    bool? crossfadeGapless,
    double? historyDuration,
    String? loudnessPreset,
    bool? preloadNext,
    double? preloadLimit,
  }) {
    return PlayerSettingsLoaded(
      skipSilence: skipSilence ?? this.skipSilence,
      showSeekButtons: showSeekButtons ?? this.showSeekButtons,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      automixBeatAlign: automixBeatAlign ?? this.automixBeatAlign,
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
      persistentQueue: persistentQueue ?? this.persistentQueue,
      autoLoadMore: autoLoadMore ?? this.autoLoadMore,
      similarContent: similarContent ?? this.similarContent,
      autoSkipOnError: autoSkipOnError ?? this.autoSkipOnError,
      rememberShuffleRepeat: rememberShuffleRepeat ?? this.rememberShuffleRepeat,
      preventDuplicates: preventDuplicates ?? this.preventDuplicates,
      autoDownloadOnLike: autoDownloadOnLike ?? this.autoDownloadOnLike,
      progressiveSeek: progressiveSeek ?? this.progressiveSeek,
      crossfadeGapless: crossfadeGapless ?? this.crossfadeGapless,
      historyDuration: historyDuration ?? this.historyDuration,
      loudnessPreset: loudnessPreset ?? this.loudnessPreset,
      preloadNext: preloadNext ?? this.preloadNext,
      preloadLimit: preloadLimit ?? this.preloadLimit,
    );
  }
}
