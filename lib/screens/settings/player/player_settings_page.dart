import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../generated/l10n.dart';
import '../../../services/audio_device_service.dart';
import '../../../services/settings_manager.dart';
import '../widgets/setting_item.dart';
import '../widgets/settings_list.dart';
import 'cubit/player_settings_cubit.dart';
import '../../../../core/widgets/back_button.dart';

/// Desktop "Player & Audio" settings. Port of the Android `PlayerSettings`
/// screen: network/streaming quality, audio DSP, output device selection and
/// Cast/remote control. Previously this page was empty on Windows.
class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayerSettingsCubit(),
      child: Scaffold(
        appBar: AppBar(
        leading: echoBackButton(context),
        title: Text(S.of(context).Audio_And_Playback),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<PlayerSettingsCubit, PlayerSettingsState>(
              builder: (context, state) {
                final s = state as PlayerSettingsLoaded;
                final cubit = context.read<PlayerSettingsCubit>();

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    // -------------------------------------------------- Network
                    GroupTitle(title: S.of(context).NetworkQuality),
                    SettingTile(
                      title: S.of(context).Streaming_Quality,
                      subtitle: S.of(context).AudioQualityCeilingOverWiFiNetwork,
                      leading: const Icon(Icons.wifi),
                      isFirst: true,
                      trailing: DropdownButton<dynamic>(
                        value: s.streamingQuality,
                        underline: const SizedBox(),
                        items: [
                          for (final q in cubit.audioQualities)
                            DropdownMenuItem(
                              value: q,
                              child: Text(
                                q == AudioQuality.flac
                                    ? 'FLAC (Monochrome)'
                                    : q.name.toUpperCase(),
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) cubit.setStreamingQuality(v);
                        },
                      ),
                    ),
                    SettingSwitchTile(
                      title: S.of(context).DataSaver,
                      subtitle: S.of(context).ForceLowBitrateAndDisablePreloading,
                      leading: const Icon(Icons.data_saver_off),
                      isLast: true,
                      value: s.dataSaver,
                      onChanged: cubit.setDataSaver,
                    ),

                    // --------------------------------------------- Audio / DSP
                    GroupTitle(title: S.of(context).AudioProcessing),
                    SettingSwitchTile(
                      title: S.of(context).AudioNormalization,
                      subtitle: S.of(context).ReplayGainLoudnessNormalizationViaPlaybackGain,
                      leading: const Icon(Icons.volume_up),
                      isFirst: true,
                      value: s.audioNormalization,
                      onChanged: cubit.setAudioNormalization,
                    ),
                    SettingEmptyTile(
                      isLast: !s.audioNormalization,
                      leading: const Icon(Icons.tune),
                      child: ListTile(
                        title: const Text('Loudness target gain',
                            style: TextStyle(fontSize: 16)),
                        subtitle: Slider(
                          value: s.loudnessGain,
                          min: -10,
                          max: 10,
                          divisions: 20,
                          label: '${s.loudnessGain.toStringAsFixed(1)} dB',
                          onChanged: s.audioNormalization
                              ? cubit.setLoudnessGain
                              : null,
                        ),
                      ),
                    ),
                    if (s.audioNormalization)
                      SettingSwitchTile(
                        title: S.of(context).SkipSilence,
                        subtitle: S.of(context).TrimSilentPartsMpvSilenceremoveOnDesktop,
                        leading: const Icon(Icons.fast_forward),
                        value: s.skipSilence,
                        onChanged: cubit.setSkipSilence,
                      ),
                    SettingSwitchTile(
                      title: S.of(context).Crossfade,
                      subtitle: S.of(context).BlendTheEndOfASongIntoTheNext,
                      leading: const Icon(Icons.graphic_eq),
                      value: s.crossfadeEnabled,
                      onChanged: cubit.setCrossfadeEnabled,
                    ),
                    if (s.crossfadeEnabled)
                      SettingSwitchTile(
                        title: S.of(context).AutomixAllineaAlBeat,
                        subtitle: S.of(context).IlBlendFinisceSuUnBeatDellaTraccia,
                        leading: const Icon(Icons.align_vertical_center),
                        value: s.automixBeatAlign,
                        onChanged: cubit.setAutomixBeatAlign,
                      ),
                    if (s.crossfadeEnabled)
                      SettingEmptyTile(
                        leading: const Icon(Icons.timeline),
                        child: ListTile(
                          title: const Text('Crossfade duration',
                              style: TextStyle(fontSize: 16)),
                          subtitle: Slider(
                            value: s.crossfadeDuration,
                            min: 1,
                            max: 15,
                            divisions: 14,
                            label: '${s.crossfadeDuration.round()} s',
                            onChanged: cubit.setCrossfadeDuration,
                          ),
                        ),
                      ),
                    if (s.crossfadeEnabled && s.automixBeatAlign)
                      SettingSwitchTile(
                        title: S.of(context).AutomixMixingArmonico,
                        subtitle: S.of(context).SceglieIlBranoSuccessivoInTonalitCompatibileCame,
                        leading: const Icon(Icons.grid_3x3),
                        value: s.automixHarmonicMix,
                        onChanged: cubit.setAutomixHarmonicMix,
                      ),
                    SettingTile(
                      title: S.of(context).DiagnosticaAutomix,
                      subtitle: S.of(context).StatoAnalisiBeatMixPointELogEventi,
                      leading: const Icon(Icons.monitor_heart_outlined),
                      onTap: () =>
                          context.go('/settings/player/automix_debug'),
                    ),
                    SettingSwitchTile(
                      title: S.of(context).Show10SecondSeekButtons,
                      leading: const Icon(Icons.replay_10),
                      isLast: true,
                      value: s.showSeekButtons,
                      onChanged: cubit.setShowSeekButtons,
                    ),

                    // ------------------------------------------- Output device
                    GroupTitle(title: S.of(context).OutputDevice),
                    SettingTile(
                      title: S.of(context).AudioOutput,
                      subtitle: s.audioDevices.isEmpty
                          ? 'Scanning devices…'
                          : _deviceName(s),
                      leading: const Icon(Icons.speaker),
                      isFirst: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: S.of(context).RefreshDevices,
                        onPressed: cubit.refreshDevices,
                      ),
                      onTap: () => _showDevicePicker(context, s, cubit),
                    ),

                    // -------------------------------------------------- Queue
                    GroupTitle(title: S.of(context).Queue),
                    SettingSwitchTile(
                      title: S.of(context).PersistentQueue,
                      subtitle: S.of(context).RestoreTheLastQueueOnAppStart,
                      leading: const Icon(Icons.restore),
                      isFirst: true,
                      value: s.persistentQueue,
                      onChanged: cubit.setPersistentQueue,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).AutoLoadMoreSongs,
                      subtitle: S.of(context).AddSongsWhenTheQueueRunsLow,
                      leading: const Icon(Icons.auto_awesome_motion),
                      value: s.autoLoadMore,
                      onChanged: cubit.setAutoLoadMore,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).EnableSimilarContent,
                      subtitle: S.of(context).AddSimilarSongsAtTheEndOfTheQueue,
                      leading: const Icon(Icons.recommend),
                      value: s.similarContent,
                      onChanged: cubit.setSimilarContent,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).RememberShuffleAndRepeat,
                      leading: const Icon(Icons.repeat),
                      value: s.rememberShuffleRepeat,
                      onChanged: cubit.setRememberShuffleRepeat,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).PreventDuplicateTracksInQueue,
                      leading: const Icon(Icons.filter_alt_off),
                      value: s.preventDuplicates,
                      onChanged: cubit.setPreventDuplicates,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).AutoSkipToNextSongOnError,
                      leading: const Icon(Icons.skip_next),
                      isLast: true,
                      value: s.autoSkipOnError,
                      onChanged: cubit.setAutoSkipOnError,
                    ),

                    // -------------------------------------------------- Misc
                    GroupTitle(title: S.of(context).Misc),
                    SettingSwitchTile(
                      title: S.of(context).ProgressiveSeek,
                      subtitle: S.of(context).Add5ExtraSecondsOnEachSeek,
                      leading: const Icon(Icons.forward_5),
                      isFirst: true,
                      value: s.progressiveSeek,
                      onChanged: cubit.setProgressiveSeek,
                    ),
                    SettingEmptyTile(
                      leading: const Icon(Icons.history),
                      child: ListTile(
                        title: const Text('History duration (months)',
                            style: TextStyle(fontSize: 16)),
                        subtitle: Slider(
                          value: s.historyDuration,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '${s.historyDuration.round()}',
                          onChanged: cubit.setHistoryDuration,
                        ),
                      ),
                    ),
                    SettingTile(
                      title: S.of(context).LoudnessPreset,
                      subtitle: s.loudnessPreset,
                      leading: const Icon(Icons.graphic_eq),
                      trailing: DropdownButton<String>(
                        value: s.loudnessPreset,
                        underline: const SizedBox(),
                        items: const ['Quiet', 'Normal', 'Loud', 'Aggressive']
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cubit.setLoudnessPreset(v);
                        },
                      ),
                    ),
                    SettingSwitchTile(
                      title: S.of(context).PreloadNextSong,
                      subtitle: S.of(context).CacheTheNextSongForGaplessPlayback,
                      leading: const Icon(Icons.downloading),
                      value: s.preloadNext,
                      onChanged: cubit.setPreloadNext,
                    ),
                    SettingSwitchTile(
                      title: "Disable crossfade for gapless albums",
                      leading: const Icon(Icons.album),
                      value: s.crossfadeGapless,
                      onChanged: cubit.setCrossfadeGapless,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).AutoDownloadOnLike,
                      leading: const Icon(Icons.download_for_offline),
                      isLast: true,
                      value: s.autoDownloadOnLike,
                      onChanged: cubit.setAutoDownloadOnLike,
                    ),

                    // --------------------------------------------- Cast / LAN
                    GroupTitle(title: S.of(context).CastRemoteControl),
                    SettingSwitchTile(
                      title: S.of(context).GoogleCast,
                      subtitle: S.of(context).EnableCastDeviceDiscovery,
                      leading: const Icon(Icons.cast),
                      isFirst: true,
                      value: s.castEnabled,
                      onChanged: cubit.setCastEnabled,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).RemoteControlLAN,
                      subtitle: s.remoteControlUrl ??
                          'Control playback from another device on your Wi-Fi',
                      leading: const Icon(Icons.devices_other),
                      isLast: true,
                      value: s.remoteControlEnabled,
                      onChanged: cubit.setRemoteControlEnabled,
                    ),

                    // Infeasible Android internals — explicit future-update notes.
                    GroupTitle(title: S.of(context).AdvancedPlayback),
                    SettingTile(
                      title: S.of(context).PlaybackCutoffGuard,
                      subtitle: S.of(context).PreArmAdattivoAttivo2035S,
                      leading: const Icon(Icons.timelapse),
                      isFirst: true,
                      onTap: () =>
                          context.go('/settings/player/automix_debug'),
                    ),
                    SettingTile(
                      title: S.of(context).AXIONAutoEqEngine,
                      subtitle: S.of(context).M10BandeApplicateAlFiltroAudio,
                      leading: const Icon(Icons.equalizer),
                      onTap: () => context.go('/settings/player/axion'),
                    ),
                    _comingSoon(
                      context,
                      title: S.of(context).BitPerfectUSBDACOutput,
                      feature: 'Direct UAC1/UAC2 driver bypass (Android audio '
                          'HAL only).',
                      isLast: true,
                    ),
                    const SizedBox(height: 100), // extra padding for miniplayer
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _comingSoon(
    BuildContext context, {
    required String title,
    required String feature,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return SettingTile(
      title: title,
      subtitle: S.of(context).ComingInAFutureUpdate,
      leading: const Icon(Icons.schedule),
      isFirst: isFirst,
      isLast: isLast,
      trailing: const Icon(Icons.schedule, size: 18),
      onTap: () => context.go(
        '/settings/coming_soon',
        extra: {'title': title, 'feature': feature},
      ),
    );
  }

  String _deviceName(PlayerSettingsLoaded s) {
    for (final d in s.audioDevices) {
      if (d.id == s.audioDeviceId) return d.name;
    }
    return s.audioDevices.isEmpty
        ? 'Dispositivo predefinito'
        : s.audioDevices.first.name;
  }

  void _showDevicePicker(
    BuildContext context,
    PlayerSettingsLoaded s,
    PlayerSettingsCubit cubit,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio output device'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in s.audioDevices)
                ListTile(
                  title: Text(d.name),
                  leading: Icon(d.id == s.audioDeviceId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  onTap: () {
                    cubit.setAudioDevice(d.id);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
