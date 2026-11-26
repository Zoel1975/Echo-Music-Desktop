import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/services/cast/cast_service.dart';
import 'package:Echo/services/download_manager.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/services/scrobble_service.dart';
import 'package:Echo/utils/song_thumbnail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/echo_surface.dart';
import '../../core/widgets/motion_effects.dart';
import 'widgets/animated_gradient_bg.dart';
import 'widgets/comment_sheet.dart';
import 'widgets/player_background.dart';

import '../../services/audio_source_info.dart';
import '../../services/automix_debug.dart';
import '../../services/media_player.dart';
import '../../services/player_layout.dart';
import '../../services/settings_manager.dart';
import '../../services/stem_mixer_service.dart';
import '../../services/video_backdrop_service.dart';
import 'widgets/video_backdrop.dart';
import '../../themes/dark.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../utils/bottom_modals.dart' hide AnimatedBuilder;
import '../../ytmusic/ytmusic.dart';
import 'widgets/lyrics_box.dart' hide AnimatedBuilder;
import 'widgets/queue_list.dart';

String _fmtMs(int? ms) => ms == null ? '—' : '${(ms / 1000).toStringAsFixed(1)}s';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.videoId});
  final String? videoId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late PanelController panelController;
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  Color? color;
  List<Color> paletteColors = [];
  bool fetchedSong = false;
  late MediaItem? currentSong;
  bool _hasLyrics = false;
  bool _lyricsLoading = true;
  final GlobalKey<State> _lyricsBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    panelController = PanelController();
    if (widget.videoId != null) {
      GetIt.I<YTMusic>().getSongDetails(widget.videoId!).then((song) {
        if (song != null) {
          GetIt.I<MediaPlayer>().playSong(song);
          setState(() {
            fetchedSong = true;
          });
        }
      });
    }
    currentSong = GetIt.I<MediaPlayer>().currentSongNotifier.value;
    GetIt.I<MediaPlayer>().currentSongNotifier.addListener(songListener);
    VideoBackdropService.instance.attach();
  }

  @override
  dispose() {
    GetIt.I<MediaPlayer>().currentSongNotifier.removeListener(songListener);
    VideoBackdropService.instance.detach();
    super.dispose();
  }

  void songListener() {
    VideoBackdropService.instance
        .onTrackChanged(GetIt.I<MediaPlayer>().currentSongNotifier.value?.id);
    if (currentSong != GetIt.I<MediaPlayer>().currentSongNotifier.value) {
      if (mounted) {
        setState(() {
          currentSong = GetIt.I<MediaPlayer>().currentSongNotifier.value;
          _lyricsLoading = true;
          _hasLyrics = false;
        });
      }
    }
  }

  Future<void> updateBackgroundColor(ImageProvider image) async {
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      maximumColorCount: 20,
    );
    if (mounted) {
      // Extract multiple colors for animated gradient
      List<Color> extractedColors = [];

      if (palette.dominantColor != null) {
        extractedColors.add(palette.dominantColor!.color);
      }
      if (palette.vibrantColor != null) {
        extractedColors.add(palette.vibrantColor!.color);
      }
      if (palette.mutedColor != null) {
        extractedColors.add(palette.mutedColor!.color);
      }
      if (palette.darkVibrantColor != null) {
        extractedColors.add(palette.darkVibrantColor!.color);
      }
      if (palette.darkMutedColor != null) {
        extractedColors.add(palette.darkMutedColor!.color);
      }
      if (palette.lightVibrantColor != null) {
        extractedColors.add(palette.lightVibrantColor!.color);
      }

      // Ensure we have at least one color
      if (extractedColors.isEmpty && palette.colors.isNotEmpty) {
        extractedColors = palette.colors.take(4).toList();
      }

      setState(() {
        color = palette.dominantColor?.color;
        paletteColors = extractedColors;
      });
    }
  }

  MaterialColor primaryWhite = const MaterialColor(
    0xFFFFFFFF,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFFFFFFF),
      200: Color(0xFFFFFFFF),
      300: Color(0xFFFFFFFF),
      400: Color(0xFFFFFFFF),
      500: Color(0xFFFFFFFF),
      600: Color(0xFFFFFFFF),
      700: Color(0xFFFFFFFF),
      800: Color(0xFFFFFFFF),
      900: Color(0xFFFFFFFF),
    },
  );

  @override
  Widget build(BuildContext context) {
    // Appearance preferences (rotation, crop, glass, play button style, ...)
    // are read from SettingsManager below. Watching it here rebuilds the
    // player as soon as a setting changes, instead of only on full restart.
    context.watch<SettingsManager>();
    // The player can be opened before anything is playing (e.g. from a deep
    // link). The rest of the tree dereferences currentSong in many places.
    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: AdaptiveIconButton(
            onPressed: () {
              // A deep-linked player may be the first route: popping it would
              // throw GoError "There is nothing to pop".
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(Icons.expand_more, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Nessun brano in riproduzione',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Theme(
      data: darkTheme(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryWhite,
          primary: primaryWhite,
          brightness: Brightness.dark,
        ),
      ),
      child: (widget.videoId != null && fetchedSong == false)
          ? const Center(
              child: AdaptiveProgressRing(),
            )
          // ignore: deprecated_member_use
          : WillPopScope(
              onWillPop: () async {
                return true;
              },
              child: Scaffold(
                key: _key,
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    // Player background: all seven Android styles.
                    Positioned.fill(
                      child: PlayerBackground(
                        style: GetIt.I<SettingsManager>().playerBackgroundStyle,
                        colors: paletteColors.isNotEmpty
                            ? paletteColors
                            : [
                                Colors.deepPurple.shade900,
                                Colors.deepPurple.shade700,
                                Colors.purple.shade800,
                                Colors.indigo.shade900,
                              ],
                        artwork: currentSong?.artUri != null
                            ? Image.network(
                                currentSong!.artUri.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              )
                            : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Beta opt-in muted video behind the player canvas.
                    const Positioned.fill(child: VideoBackdrop()),

                    // Optional Automix debug overlay (Android parity).
                    if (GetIt.I<SettingsManager>()
                        .extra<bool>('automixOverlay', false))
                      Positioned(
                        top: 54,
                        right: 16,
                        child: IgnorePointer(
                          child: ListenableBuilder(
                            listenable: AutomixDebug.instance,
                            builder: (context, _) {
                              final d = AutomixDebug.instance;
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AUTOMIX ${d.status}\n'
                                  'out ${d.outBeat?.bpm.toStringAsFixed(1) ?? '—'} '
                                  '${d.outBeat?.keyLabel ?? ''}\n'
                                  'in  ${d.inBeat?.bpm.toStringAsFixed(1) ?? '—'} '
                                  '${d.inBeat?.keyLabel ?? ''}\n'
                                  'mix ${_fmtMs(d.triggerTimeMs)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // MAIN CONTENT
                    SafeArea(
                      child: Column(
                        children: [
                          // App Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AdaptiveIconButton(
                                  onPressed: () => context.pop(),
                                  icon: Icon(AdaptiveIcons.chevron_down,
                                      color: Colors.white),
                                ),
                                Row(
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable:
                                          GetIt.I<CastService>().client.playing,
                                      builder: (context, casting, _) =>
                                          AdaptiveIconButton(
                                        onPressed: () => context.push('/cast'),
                                        icon: Icon(Icons.cast,
                                            color: casting
                                                ? Colors.greenAccent
                                                : Colors.white
                                                    .withValues(alpha: 0.7)),
                                      ),
                                    ),
                                    AdaptiveIconButton(
                                      onPressed: () =>
                                          context.push('/canvas_ambient'),
                                      icon: Icon(Icons.animation,
                                          color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                    AdaptiveIconButton(
                                      onPressed: () {
                                        _key.currentState?.openEndDrawer();
                                      },
                                      icon: Icon(AdaptiveIcons.queue,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final layout = PlayerLayoutResolver.resolve(
                                    constraints.maxWidth);
                                final bool isWide = layout == PlayerLayout.wide;
                                if (isWide) {
                                  return Stack(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // LEFT: Art & Controls (always on left now)
                                          Expanded(
                                            flex: 5,
                                            child: Center(
                                              child: Container(
                                                constraints: const BoxConstraints(
                                                    maxWidth: double.infinity),
                                                padding:
                                                    const EdgeInsets.all(40.0),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Center(
                                                        child: AspectRatio(
                                                          aspectRatio: 1,
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4),
                                                                  blurRadius:
                                                                      20,
                                                                  spreadRadius:
                                                                      5,
                                                                  offset:
                                                                      const Offset(
                                                                          0,
                                                                          10),
                                                                ),
                                                              ],
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              child: _artwork(song: currentSong!.extras!, onImageReady: updateBackgroundColor),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 40),
                                                    _buildTitleAndControls(
                                                        context,
                                                        centered: false),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // RIGHT: Lyrics or "No Lyrics" message
                                          Expanded(
                                            flex: 6,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(40.0),
                                              // One stable instance: swapping between
                                          // two differently-keyed branches recreated
                                          // the State, re-fetched lyrics and made them
                                          // flash/disappear on every status change.
                                          child: LyricsBox(
                                            key: _lyricsBoxKey,
                                            currentSong: currentSong!,
                                            size: Size(
                                              constraints.maxWidth / 2,
                                              constraints.maxHeight,
                                            ),
                                            onLyricsFound: (found) {
                                              if (mounted) {
                                                setState(() {
                                                  _hasLyrics = found;
                                                  _lyricsLoading = false;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                    ],
                                  );
                                } else {
                                  // Mobile layouts: compact (<480) and
                                  // narrow (<900) share the vertical stack but
                                  // compact uses tighter padding (Android 3rd layout).
                                  final compact = layout == PlayerLayout.compact;
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 12.0 : 24.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 20,
                                                    spreadRadius: 5,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: GetIt.I<SettingsManager>().hidePlayerThumbnail
                                                    ? const SizedBox.shrink()
                                                    : _artwork(
                                                        song: currentSong!.extras!,
                                                        onImageReady:
                                                            updateBackgroundColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildTitleAndControls(context),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                endDrawer: SizedBox(
                  width: min(400, MediaQuery.of(context).size.width) - 50,
                  child: const QueueList(),
                ),
              ),
            ),
    );
  }

  
/// Player artwork with the Android appearance gestures wired: crop, rotation,
/// swipe-to-change-song and its sensitivity.
Widget _artwork({
  required Map song,
  required void Function(ImageProvider) onImageReady,
}) {
  final settings = GetIt.I<SettingsManager>();
  final rotating = settings.extra<bool>('rotatingThumb', false);
  // A contain-fit image leaves gaps that become visible while spinning and
  // break the circular clip; force cover for the rotating record.
  final fit = rotating || settings.extra<bool>('cropArt', true)
      ? BoxFit.cover
      : BoxFit.contain;
  final sensitivity = settings.extra<double>('swipeSensitivity', 5).clamp(1, 10);
  final threshold = 900.0 / sensitivity;
  return Stack(
    alignment: Alignment.center,
    children: [
      SongSwipeDetector(
        enabled: settings.extra<bool>('swipeChangeSong', true),
        threshold: threshold,
        onNext: () => GetIt.I<MediaPlayer>().player.seekToNext(),
        onPrevious: () => GetIt.I<MediaPlayer>().player.seekToPrevious(),
        child: RotatingArt(
          enabled: rotating,
          child: SongThumbnail(
            song: song,
            fit: fit,
            onImageReady: onImageReady,
          ),
        ),
      ),
      const Positioned(
        bottom: 6,
        left: 0,
        right: 0,
        child: _StemArtworkControls(),
      ),
    ],
  );
}

/// Real-time stem controls docked on the artwork, so the user does not have
/// to open the song menu to toggle stems while the record spins.

Widget _buildTitleAndControls(BuildContext context, {bool centered = false}) {
    if (currentSong == null) return const SizedBox();
    MediaPlayer mediaPlayer = context.watch<MediaPlayer>();
    final playerSettings = GetIt.I<SettingsManager>();
    final showSeek = playerSettings.showSeekButtons;
    final progressive = playerSettings.progressiveSeek;
  final inactiveControl = switch (
      playerSettings.extra<String>('buttonColors', 'Default')) {
    'Accent' => Theme.of(context).colorScheme.primary,
    'White' => Colors.white,
    _ => Colors.white.withValues(alpha: 0.7),
  };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Top Row: [Title/Artist] [Like] [Menu]
        Row(
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            // Title and Artist
            Expanded(
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // Constrain the marquee: endless TextScroll otherwise grows
                  // past the Row and paints over the artwork/lyrics.
                  SizedBox(
                    height: 38,
                    child: TextScroll(
                      currentSong?.title ?? 'Title',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      mode: TextScrollMode.bouncing,
                      velocity: const Velocity(pixelsPerSecond: Offset(28, 0)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentSong?.artist ??
                        currentSong?.album ??
                        currentSong?.extras?['subtitle'] ??
                        '',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Effective source, not the requested quality ceiling:
                  // e.g. "FLAC 48 kHz · 24 bit · stereo · Monochrome" or
                  // "Opus 160 kbps · YouTube" (or the local file format).
                  ValueListenableBuilder<PlaybackSourceInfo?>(
                    valueListenable:
                        GetIt.I<MediaPlayer>().playbackSource,
                    builder: (context, info, _) {
                      if (info == null) return const SizedBox.shrink();
                      final detailed = GetIt.I<SettingsManager>()
                          .extra<bool>('showCodec', true);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          detailed ? info.label : info.shortLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Favorite
            ValueListenableBuilder(
              valueListenable: Hive.box('FAVOURITES').listenable(),
              builder: (context, value, child) {
                Map? item = value.get(currentSong?.extras?['videoId']);
                return HeartBurst(
                  liked: item != null,
                  onTap: () async {
                    if (item == null) {
                      await Hive.box('FAVOURITES').put(
                        currentSong!.extras!['videoId'],
                        {
                          ...currentSong!.extras!,
                          'createdAt': DateTime.now().millisecondsSinceEpoch
                        },
                      );
                      // Android's "Auto download on like": start an offline
                      // download as soon as the track becomes a Favourite.
                      if (GetIt.I<SettingsManager>().autoDownloadOnLike) {
                        unawaited(GetIt.I<DownloadManager>()
                            .downloadSong(currentSong!.extras!));
                      }
                    } else {
                      await value.delete(currentSong!.extras!['videoId']);
                    }
                    // Android's "Send Likes/Unlikes" preference.
                    final prefs = GetIt.I<SettingsManager>();
                    if (prefs.extra<bool>('lastfmLikes', false)) {
                      final song = currentSong!.extras!;
                      final apiKey = prefs.extra<String>('lastfmApiKey', '');
                      final session = prefs.extra<String>('lastfmSessionKey', '');
                      final secret = prefs.extra<String>('lastfmApiSecret', '');
                      if (apiKey.isNotEmpty && session.isNotEmpty) {
                        unawaited(GetIt.I<ScrobbleService>().sendLove(
                          apiKey: apiKey,
                          sessionKey: session,
                          secret: secret,
                          artist: song['artist']?.toString() ??
                              (song['artists'] is List &&
                                      song['artists'].isNotEmpty
                                  ? song['artists'].first['name']?.toString() ??
                                      ''
                                  : ''),
                          track: song['title']?.toString() ?? currentSong!.title,
                          loved: item == null,
                        ));
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            // Comments (Android gates this behind "Show comment button").
            if (GetIt.I<SettingsManager>().extra<bool>('showComment', false))
              AdaptiveIconButton(
                onPressed: () => CommentSheet.show(context),
                icon: Icon(
                  Icons.comment_outlined,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            // More Options
            Builder(
              builder: (buttonContext) => AdaptiveIconButton(
                onPressed: () {
                  final RenderBox renderBox =
                      buttonContext.findRenderObject() as RenderBox;
                  final position = renderBox.localToGlobal(Offset.zero);
                  final size = renderBox.size;
                  Modals.showPlayerOptionsModal(
                    context,
                    mediaPlayer.currentSongNotifier.value!.extras!,
                    buttonPosition: position,
                    buttonSize: size,
                  );
                },
                icon: Icon(
                  Icons.more_horiz,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // Progress Bar
        ListenableBuilder(
          listenable: Listenable.merge([
            mediaPlayer.progressBarState,
            StemMixerService.instance.positionNotifier,
          ]),
          builder: (context, _) {
            final mixer = StemMixerService.instance;
            final base = mediaPlayer.progressBarState.value;
            final stems = mixer.state.stemsLoaded;
            final current = stems ? mixer.position : base.current;
            final total = stems ? (mixer.totalDuration ?? base.total) : base.total;
            final buffered = stems ? Duration.zero : base.buffered;
            final sliderStyle = GetIt.I<SettingsManager>()
                .extra<String>('sliderStyle', 'Default');
            if (sliderStyle == 'Wavy' || sliderStyle == 'Squiggly') {
              final ratio = total.inMilliseconds > 0
                  ? (current.inMilliseconds /
                          total.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return Column(
                children: [
                  WavySlider(
                    value: ratio,
                    squiggly: sliderStyle == 'Squiggly',
                    onChanged: (v) {
                      final target =
                          Duration(milliseconds: (v * total.inMilliseconds).round());
                      if (stems) {
                        unawaited(mixer.seek(target));
                      } else {
                        unawaited(mediaPlayer.player.seek(target));
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        current.toString().split('.').first,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        total.toString().split('.').first,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              );
            }
            return ProgressBar(
              progress: current,
              total: total,
              buffered: buffered,
              barHeight: 4,
              thumbRadius: GetIt.I<SettingsManager>()
                  .extra<double>('thumbRadius', 6)
                  .round()
                  .toDouble(),
              baseBarColor: Colors.white.withValues(alpha: 0.3),
              bufferedBarColor: Colors.white.withValues(alpha: 0.5),
              progressBarColor: Colors.white,
              thumbColor: Colors.white,
              timeLabelTextStyle: const TextStyle(color: Colors.white),
              onSeek: (position) {
                if (stems) {
                  unawaited(mixer.seek(position));
                } else {
                  unawaited(mediaPlayer.player.seek(position));
                }
              },
            );
          },
        ),
        const SizedBox(height: 20),

        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Shuffle (same behaviour as the queue sheet)
            ValueListenableBuilder<bool>(
              valueListenable: mediaPlayer.shuffleNotifier,
              builder: (context, enabled, _) => AdaptiveIconButton(
                onPressed: () => mediaPlayer.setShuffleModeEnabled(!enabled),
                icon: Icon(
                  Icons.shuffle,
                  size: 24,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            // Previous
            AdaptiveIconButton(
              onPressed: () {
                mediaPlayer.player.seekToPrevious();
              },
              icon: Icon(
                AdaptiveIcons.skip_previous,
                size: 32,
                color: Colors.white,
              ),
            ),
            // Seek back 10s
            if (showSeek)
              AdaptiveIconButton(
                onPressed: () {
                  final mixer = StemMixerService.instance;
                  final step = mediaPlayer.seekStep(const Duration(seconds: 10),
                      progressive: progressive);
                  if (mixer.state.stemsLoaded) {
                    unawaited(mixer.seekBy(-step));
                  } else {
                    unawaited(mediaPlayer.player
                        .seek(mediaPlayer.player.position - step));
                  }
                },
                icon: Icon(
                  Icons.replay_10,
                  size: 28,
                  color: inactiveControl,
                ),
              ),
            // Play/Pause
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
          color: playerSettings.extra<bool>('appleInspired', false)
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(
              playerSettings.extra<bool>('appleInspired', false) ? 18 : 50)),
              child: ValueListenableBuilder(
                valueListenable: mediaPlayer.buttonState,
                builder: (context, ButtonState value, child) {
                  return AnimatedBuilder(
                    animation: StemMixerService.instance,
                    builder: (context, _) {
                      final mixer = StemMixerService.instance;
                      if (value == ButtonState.loading &&
                          !mixer.state.stemsLoaded) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.black));
                      }
                      final playing = mixer.state.stemsLoaded
                          ? mixer.isPlaying
                          : value == ButtonState.playing;
                      final wavy =
                          playerSettings.extra<bool>('wavyPlayPause', false);
                      return IconButton(
                        onPressed: () {
                          if (mixer.state.stemsLoaded) {
                            unawaited(mixer.setPlaying(!mixer.isPlaying));
                          } else {
                            unawaited(playing
                                ? mediaPlayer.player.pause()
                                : mediaPlayer.player.play());
                          }
                        },
                        icon: wavy
                            ? WavyPlayPause(playing: playing)
                            : Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 32,
                                color: Colors.black,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            // Next
            AdaptiveIconButton(
              onPressed: () {
                mediaPlayer.player.seekToNext();
              },
              icon: Icon(
                AdaptiveIcons.skip_next,
                size: 32,
                color: Colors.white,
              ),
            ),
            // Seek forward 10s
            if (showSeek)
              AdaptiveIconButton(
                onPressed: () {
                  final mixer = StemMixerService.instance;
                  final step = mediaPlayer.seekStep(const Duration(seconds: 10),
                      progressive: progressive);
                  if (mixer.state.stemsLoaded) {
                    unawaited(mixer.seekBy(step));
                  } else {
                    unawaited(mediaPlayer.player
                        .seek(mediaPlayer.player.position + step));
                  }
                },
                icon: Icon(
                  Icons.forward_10,
                  size: 28,
                  color: inactiveControl,
                ),
              ),
            // Repeat
            ValueListenableBuilder(
                valueListenable: mediaPlayer.loopMode,
                builder: (context, value, child) {
                  return AdaptiveIconButton(
                    onPressed: () {
                      mediaPlayer.changeLoopMode();
                    },
                    icon: Icon(
                      value == LoopMode.off || value == LoopMode.all
                          ? AdaptiveIcons.repeat_all
                          : AdaptiveIcons.repeat_one,
                      size: 24,
                      color: value == LoopMode.off
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white,
                    ),
                  );
                }),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StemArtworkControls extends StatelessWidget {
  const _StemArtworkControls();

  @override
  Widget build(BuildContext context) {
    final mixer = StemMixerService.instance;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: AnimatedBuilder(
        animation: mixer,
        builder: (context, _) {
          final state = mixer.state;
          return EchoSurface(
            radius: BorderRadius.circular(EchoTokens.floatingBarRadius),
            padding: const EdgeInsets.symmetric(
                horizontal: EchoTokens.space2, vertical: EchoTokens.space1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_split, size: 16, color: scheme.primary),
                const SizedBox(width: EchoTokens.space1),
                ...List.generate(4, (i) {
                  return Tooltip(
                    message: '${stemNames[i]} (${stemKeys[i]} — tap to toggle, '
                        'hold to mute)',
                    child: _stemChip(
                      label: stemShortNames[i],
                      color: stemColors[i],
                      active: state.stemsLoaded && state.enabled[i],
                      enabled: state.stemsLoaded,
                      scheme: scheme,
                      onTap: () => mixer.setStemEnabled(i, !state.enabled[i]),
                    ),
                  );
                }),
                Tooltip(
                  message: 'All stem options',
                  child: _stemChip(
                    label: 'MORE',
                    color: scheme.primary,
                    active: false,
                    enabled: true,
                    scheme: scheme,
                    onTap: () => Modals.showStemsSheet(
                      context,
                      GetIt.I<MediaPlayer>().currentSongNotifier.value?.extras ??
                          {},
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _stemChip({
    required String label,
    required Color color,
    required bool active,
    required bool enabled,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(EchoTokens.cornerSmall),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: EchoTokens.space2, vertical: EchoTokens.space1),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(EchoTokens.cornerSmall),
          border: Border.all(
            color: active ? color : scheme.outlineVariant.withValues(alpha: 0.4),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? color : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: EchoTokens.space1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: !enabled
                    ? scheme.onSurface.withValues(alpha: 0.35)
                    : active
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
