import 'package:flutter/material.dart';
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
                    const SettingNoticeTile(
                      message: 'Alcune opzioni Queue/Misc provengono dall\'app '
                          'Android e non sono ancora applicate al player desktop.',
                    ),
                    // -------------------------------------------------- Network
                    const GroupTitle(title: 'Network & quality'),
                    SettingTile(
                      title: S.of(context).Streaming_Quality,
                      subtitle: 'Audio quality ceiling over Wi-Fi / network',
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
                      title: 'Data Saver',
                      subtitle: 'Force low bitrate and disable preloading',
                      leading: const Icon(Icons.data_saver_off),
                      isLast: true,
                      value: s.dataSaver,
                      onChanged: cubit.setDataSaver,
                    ),

                    // --------------------------------------------- Audio / DSP
                    const GroupTitle(title: 'Audio processing'),
                    SettingSwitchTile(
                      title: 'Audio normalization',
                      subtitle: 'ReplayGain loudness normalization (via playback gain)',
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
                        title: 'Skip silence',
                        subtitle: 'Trim silent parts (mpv silenceremove on desktop)',
                        leading: const Icon(Icons.fast_forward),
                        value: s.skipSilence,
                        onChanged: cubit.setSkipSilence,
                      ),
                    SettingSwitchTile(
                      title: 'Crossfade',
                      subtitle: 'Blend the end of a song into the next',
                      leading: const Icon(Icons.graphic_eq),
                      value: s.crossfadeEnabled,
                      onChanged: cubit.setCrossfadeEnabled,
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
                    SettingSwitchTile(
                      title: 'Show 10-second seek buttons',
                      leading: const Icon(Icons.replay_10),
                      isLast: true,
                      value: s.showSeekButtons,
                      onChanged: cubit.setShowSeekButtons,
                    ),

                    // ------------------------------------------- Output device
                    const GroupTitle(title: 'Output device'),
                    SettingTile(
                      title: 'Audio output',
                      subtitle: s.audioDevices.isEmpty
                          ? 'Scanning devices…'
                          : _deviceName(s),
                      leading: const Icon(Icons.speaker),
                      isFirst: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh devices',
                        onPressed: cubit.refreshDevices,
                      ),
                      onTap: () => _showDevicePicker(context, s, cubit),
                    ),

                    // -------------------------------------------------- Queue
                    const GroupTitle(title: 'Queue'),
                    SettingSwitchTile(
                      title: 'Persistent queue',
                      subtitle: 'Restore the last queue on app start',
                      leading: const Icon(Icons.restore),
                      isFirst: true,
                      value: s.persistentQueue,
                      onChanged: cubit.setPersistentQueue,
                    ),
                    SettingSwitchTile(
                      title: 'Auto load more songs',
                      subtitle: 'Add songs when the queue runs low',
                      leading: const Icon(Icons.auto_awesome_motion),
                      value: s.autoLoadMore,
                      onChanged: cubit.setAutoLoadMore,
                    ),
                    SettingSwitchTile(
                      title: 'Enable similar content',
                      subtitle: 'Add similar songs at the end of the queue',
                      leading: const Icon(Icons.recommend),
                      value: s.similarContent,
                      onChanged: cubit.setSimilarContent,
                    ),
                    SettingSwitchTile(
                      title: 'Remember shuffle and repeat',
                      leading: const Icon(Icons.repeat),
                      value: s.rememberShuffleRepeat,
                      onChanged: cubit.setRememberShuffleRepeat,
                    ),
                    SettingSwitchTile(
                      title: 'Prevent duplicate tracks in queue',
                      leading: const Icon(Icons.filter_alt_off),
                      value: s.preventDuplicates,
                      onChanged: cubit.setPreventDuplicates,
                    ),
                    SettingSwitchTile(
                      title: 'Auto skip to next song on error',
                      leading: const Icon(Icons.skip_next),
                      isLast: true,
                      value: s.autoSkipOnError,
                      onChanged: cubit.setAutoSkipOnError,
                    ),

                    // -------------------------------------------------- Misc
                    const GroupTitle(title: 'Misc'),
                    SettingSwitchTile(
                      title: 'Progressive seek',
                      subtitle: 'Add 5 extra seconds on each seek',
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
                      title: 'Loudness preset',
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
                      title: 'Preload next song',
                      subtitle: 'Cache the next song for gapless playback',
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
                      title: 'Auto download on like',
                      leading: const Icon(Icons.download_for_offline),
                      isLast: true,
                      value: s.autoDownloadOnLike,
                      onChanged: cubit.setAutoDownloadOnLike,
                    ),

                    // --------------------------------------------- Cast / LAN
                    const GroupTitle(title: 'Cast & remote control'),
                    SettingSwitchTile(
                      title: 'Google Cast',
                      subtitle: 'Enable Cast device discovery',
                      leading: const Icon(Icons.cast),
                      isFirst: true,
                      value: s.castEnabled,
                      onChanged: cubit.setCastEnabled,
                    ),
                    SettingSwitchTile(
                      title: 'Remote control (LAN)',
                      subtitle: s.remoteControlUrl ??
                          'Control playback from another device on your Wi-Fi',
                      leading: const Icon(Icons.devices_other),
                      isLast: true,
                      value: s.remoteControlEnabled,
                      onChanged: cubit.setRemoteControlEnabled,
                    ),

                    // Infeasible Android internals — explicit future-update notes.
                    const GroupTitle(title: 'Advanced playback'),
                    _comingSoon(
                      context,
                      title: 'Playback cutoff guard',
                      feature: 'Adaptive end-of-track pre-arming to avoid '
                          'playback gaps.',
                      isFirst: true,
                    ),
                    _comingSoon(
                      context,
                      title: 'Bit-perfect USB DAC output',
                      feature: 'Direct UAC1/UAC2 driver bypass (Android audio '
                          'HAL only).',
                    ),
                    _comingSoon(
                      context,
                      title: 'AXION / AutoEq engine',
                      feature: 'Pro-grade DSP with headphone AutoEq profiles.',
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
      subtitle: 'Coming in a future update',
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
    return s.audioDevices.first.name;
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
