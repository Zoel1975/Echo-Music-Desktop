import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/screens/settings/player/equalizer/cubit/equalizer_cubit.dart';
import 'package:Echo/screens/settings/player/equalizer/cubit/equalizer_state.dart';
import 'package:Echo/screens/settings/player/equalizer/cubit/loudness_cubit.dart';
import 'package:Echo/screens/settings/player/equalizer/cubit/loudness_state.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:Echo/screens/settings/widgets/setting_item.dart';
import 'package:Echo/screens/settings/widgets/settings_list.dart';
import 'package:Echo/services/axion_eq_service.dart';
import 'package:Echo/services/eq_settings.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/themes/text_styles.dart';
import 'package:Echo/utils/adaptive_widgets/slider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import '../../../../../core/widgets/back_button.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  // Built once: recreating the cubits on every rebuild lost slider state.
  late final Future<Widget> _view;

  @override
  void initState() {
    super.initState();
    _view = _build();
  }

  Future<Widget> _build() async {
    final settings = GetIt.I<SettingsManager>();
    final List<EqBand> bands;
    final double minDb;
    final double maxDb;

    if (Platform.isAndroid) {
      final params = await GetIt.I<AndroidEqualizer>().parameters;
      minDb = params.minDecibels;
      maxDb = params.maxDecibels;
      bands = params.bands
          .map(
            (b) => EqBand(
              index: b.index,
              centerFrequency: b.centerFrequency,
              gain: b.gain,
            ),
          )
          .toList();
    } else {
      // Desktop has no AndroidEqualizer in GetIt: expose the same 10 bands
      // backed by the persisted EQ gains and mpv's equalizer filter.
      minDb = -15.0;
      maxDb = 15.0;
      final gains =
          EqSettings.savedGains(settings) ?? List<double>.filled(10, 0.0);
      bands = List.generate(
        10,
        (i) => EqBand(
          index: i,
          centerFrequency: eqFrequencies[i],
          gain: gains[i],
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: EqualizerCubit(
            enabled: settings.equalizerEnabled,
            minDb: minDb,
            maxDb: maxDb,
            bands: bands,
          ),
        ),
        BlocProvider.value(
          value: LoudnessCubit(
            enabled: settings.loudnessEnabled,
            targetGain: settings.loudnessTargetGain,
          ),
        ),
      ],
      child: const _EqualizerView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _view,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equalizer')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Errore equalizzatore: ${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: ExpressiveLoadingIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

class _EqualizerView extends StatelessWidget {
  const _EqualizerView();

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final settings = GetIt.I<SettingsManager>();

    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: Text(
          S.of(context).Loudness_And_Equalizer,
          style: mediumTextStyle(context, bold: false),
        ),
        centerTitle: true,
      ),
      body: SettingsList(
        children: [
          /// LOUDNESS
          GroupTitle(title: "Loudness"),
          BlocBuilder<LoudnessCubit, LoudnessState>(
            builder: (context, state) {
              return SettingSwitchTile(
                leading: const Icon(Icons.volume_up),
                title: S.of(context).Loudness_Enhancer,
                isFirst: true,
                value: state.enabled,
                onChanged: (val) async {
                  context.read<LoudnessCubit>().toggle(val);
                  await mediaPlayer.setLoudnessEnabled(val);
                },
              );
            },
          ),
          SettingEmptyTile(
            isLast: true,
            child: BlocBuilder<LoudnessCubit, LoudnessState>(
              builder: (context, state) {
                return Slider(
                  min: -10,
                  max: 10,
                  value: state.targetGain.clamp(-10.0, 10.0),
                  onChanged: state.enabled
                      ? (val) async {
                          context.read<LoudnessCubit>().setTargetGain(val);
                          await mediaPlayer.setLoudnessTargetGain(val);
                        }
                      : null,
                );
              },
            ),
          ),

          /// EQUALIZER
          GroupTitle(title: "Equalizer"),
          BlocBuilder<EqualizerCubit, EqualizerState>(
            builder: (context, state) {
              return SettingSwitchTile(
                leading: const Icon(Icons.equalizer),
                title: S.of(context).Enable_Equalizer,
                isFirst: true,
                value: state.enabled,
                onChanged: (val) async {
                  context.read<EqualizerCubit>().toggle(val);
                  await mediaPlayer.setEqualizerEnabled(val);
                },
              );
            },
          ),
          SettingEmptyTile(
            isLast: true,
            child: BlocBuilder<EqualizerCubit, EqualizerState>(
              builder: (context, state) {
                if (!state.enabled) return const SizedBox();

                return SizedBox(
                  height: 250,
                  child: Row(
                    children: [
                      for (final band in state.bands)
                        Expanded(
                          child: Column(
                            children: [
                              Text(band.gain.toStringAsFixed(1)),
                              Expanded(
                                child: AdaptiveSlider(
                                  vertical: true,
                                  min: state.minDb,
                                  max: state.maxDb,
                                  value: band.gain,
                                  onChanged: (val) async {
                                    context
                                        .read<EqualizerCubit>()
                                        .setBandGain(band.index, val);

                                    if (Platform.isAndroid) {
                                      await settings.setEqualizerBandsGain(
                                          band.index, val);
                                      final params =
                                          await GetIt.I<AndroidEqualizer>()
                                              .parameters;
                                      await params.bands[band.index]
                                          .setGain(val);
                                    } else {
                                      final gains = List<double>.from(
                                        EqSettings.savedGains(settings) ??
                                            List<double>.filled(10, 0.0),
                                      );
                                      while (gains.length < 10) {
                                        gains.add(0.0);
                                      }
                                      gains[band.index] = val;
                                      settings.equalizerBandsGain = gains;
                                      EqSettings.apply(settings);
                                      await mediaPlayer.reloadCurrentSource();
                                    }
                                  },
                                ),
                              ),
                              Text('${band.centerFrequency.round()} Hz'),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
