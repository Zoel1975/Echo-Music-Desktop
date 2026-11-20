import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../generated/l10n.dart';
import '../../../services/audio_device_service.dart';
import '../../../services/settings_manager.dart';
import '../widgets/setting_item.dart';
import 'cubit/player_settings_cubit.dart';

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
                          DropdownMenuItem(
                            value: AudioQuality.high,
                            child: const Text('HIGH'),
                          ),
                          DropdownMenuItem(
                            value: AudioQuality.low,
                            child: const Text('LOW'),
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
                      subtitle: 'ReplayGain-style loudness normalization',
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
