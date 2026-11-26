import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/services/cast/cast_device.dart';
import 'package:Echo/services/cast/cast_service.dart';
import 'package:Echo/core/widgets/echo_surface.dart';
import 'package:Echo/core/widgets/motion_effects.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/services/stem_mixer_service.dart';
import 'package:Echo/utils/adaptive_widgets/buttons.dart';
import 'package:Echo/utils/adaptive_widgets/progress_ring.dart';
import 'package:Echo/utils/song_thumbnail.dart';
import 'package:provider/provider.dart';

/// Palette colors extracted from album art can be almost white. Returned color
/// is always dark enough for the white mini-player labels to stay readable.
Color readableMiniPlayerBackground(Color source) {
  double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  var color = source;
  for (var t = 0.0; t <= 1.0; t += 0.1) {
    color = Color.lerp(source, Colors.black, t) ?? Colors.black;
    if (luminance(color) <= 0.22) break;
  }
  return color;
}

class BottomPlayer extends StatefulWidget {
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> {
  Color? backgroundColor;



  void updateBackgroundColor(ImageProvider image) async {
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      maximumColorCount: 20,
    );
    if (!mounted) return;
    final source = palette.darkVibrantColor?.color ??
        palette.darkMutedColor?.color ??
        palette.vibrantColor?.color ??
        palette.dominantColor?.color;
    if (source == null) return;
    final readable = readableMiniPlayerBackground(source);
    if (backgroundColor != readable) {
      setState(() => backgroundColor = readable);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Rebuild when appearance settings (mini-player style, glass) change,
    // without requiring a Provider ancestor.
    if (!GetIt.I.isRegistered<SettingsManager>()) return _buildPlayer(context);
    return AnimatedBuilder(
      animation: GetIt.I<SettingsManager>(),
      builder: (context, _) => _buildPlayer(context),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    return StreamBuilder(
        stream: mediaPlayer.currentTrackStream,
        builder: (
          context,
          snapshot,
        ) {
          final data = snapshot.data;
          final currentSong = data?.currentItem;
          if (currentSong == null) {
            return const SizedBox(); // or loading indicator
          }
          // The palette is darkened before use, so white labels always have
          // enough contrast even for very light album covers.
          const foreground = Colors.white;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GestureDetector(
              onTap: () {
                context.push('/player');
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EchoSurface(
                  color: () {
                    final base = backgroundColor ?? const Color(0xFF202020);
                    return switch (GetIt.I<SettingsManager>().miniPlayerStyle) {
                      'Glass' => base.withAlpha(215),
                      'Gradient' => base.withAlpha(240),
                      _ => base.withAlpha(255), // Solid
                    };
                  }(),
                  radius: const BorderRadius.all(Radius.circular(50)),
                  vibrancy: GetIt.I<SettingsManager>()
                              .extra<bool>('glassMiniPlayer', true) &&
                          GetIt.I<SettingsManager>().miniPlayerStyle == 'Glass'
                      ? 1.3
                      : 0.0,
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4), // Reduced padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // LEFT: Song Info (Art + Text)
                          Expanded(
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: SongThumbnail(
                                    song: currentSong.extras!,
                                    dp: MediaQuery.of(context)
                                        .devicePixelRatio,
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.fill,
                                    onImageReady: updateBackgroundColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MarqueeText(
                                        currentSong.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: foreground,
                                        ),
                                      ),
                                      if (currentSong.artist != null ||
                                          currentSong.extras!['subtitle'] !=
                                              null)
                                        MarqueeText(
                                          currentSong.artist ??
                                              currentSong
                                                  .extras!['subtitle'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                foreground
                                                    .withValues(alpha: 0.8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // RIGHT: Controls (Prev, Play/Pause, Next)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder(
                                stream: context
                                    .watch<MediaPlayer>()
                                    .player
                                    .sequenceStateStream,
                                builder: (context, snapshot) {
                                  return AdaptiveIconButton(
                                    onPressed: () {
                                      GetIt.I<MediaPlayer>()
                                          .player
                                          .seekToPrevious();
                                    },
                                    icon: const Icon(
                                      Icons.skip_previous,
                                      size: 24,
                                      color: foreground,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              ValueListenableBuilder(
                                valueListenable:
                                    GetIt.I<MediaPlayer>().buttonState,
                                builder: (context, buttonState, child) {
                                  return AnimatedBuilder(
                                    animation: StemMixerService.instance,
                                    builder: (context, _) {
                                      final mixer = StemMixerService.instance;
                                      final stems = mixer.state.stemsLoaded;
                                      if (!stems &&
                                          buttonState == ButtonState.loading) {
                                        return const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: AdaptiveProgressRing(),
                                        );
                                      }
                                      final playing = stems
                                          ? mixer.isPlaying
                                          : buttonState == ButtonState.playing;
                                      return AdaptiveIconButton(
                                        onPressed: () {
                                          if (mixer.state.stemsLoaded) {
                                            unawaited(mixer
                                                .setPlaying(!mixer.isPlaying));
                                          } else {
                                            final p =
                                                GetIt.I<MediaPlayer>().player;
                                            unawaited(
                                                p.playing ? p.pause() : p.play());
                                          }
                                        },
                                        icon: Icon(
                                          playing ? Icons.pause : Icons.play_arrow,
                                          size: 30,
                                          color: foreground,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              StreamBuilder(
                                stream: context
                                    .watch<MediaPlayer>()
                                    .player
                                    .sequenceStateStream,
                                builder: (context, snapshot) {
                                  return AdaptiveIconButton(
                                    onPressed: () {
                                      GetIt.I<MediaPlayer>()
                                          .player
                                          .seekToNext();
                                    },
                                    icon: const Icon(
                                      Icons.skip_next,
                                      size: 24,
                                      color: foreground,
                                    ),
                                  );
                                },
                              ),
                              ValueListenableBuilder<CastDevice?>(
                                valueListenable:
                                    GetIt.I<CastService>().connected,
                                builder: (context, device, _) =>
                                    AdaptiveIconButton(
                                  onPressed: () => context.push('/cast'),
                                  icon: Icon(
                                    device == null ? Icons.cast : Icons.cast_connected,
                                    size: 20,
                                    color: device == null
                                        ? foreground.withValues(alpha: 0.7)
                                        : Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            );
        });
  }
}