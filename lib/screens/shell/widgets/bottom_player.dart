import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/core/theme/tokens.dart';
import 'package:Echo/utils/adaptive_widgets/buttons.dart';
import 'package:Echo/utils/adaptive_widgets/progress_ring.dart';
import 'package:Echo/utils/song_thumbnail.dart';
import 'package:provider/provider.dart';

class BottomPlayer extends StatefulWidget {
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> {
  @override
  Widget build(BuildContext context) {
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
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GestureDetector(
              onTap: () {
                context.push('/player');
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: EchoTokens.paper2,
                  border: Border(top: BorderSide(color: EchoTokens.rule, width: 1)),
                ),
                child: ClipRRect(
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
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentSong.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (currentSong.artist != null ||
                                          currentSong.extras!['subtitle'] !=
                                              null)
                                        Text(
                                          currentSong.artist ??
                                              currentSong
                                                  .extras!['subtitle'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.white.withValues(alpha: 0.8),
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
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              ValueListenableBuilder(
                                valueListenable:
                                    GetIt.I<MediaPlayer>().buttonState,
                                builder: (context, buttonState, child) {
                                  return (buttonState == ButtonState.loading)
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: AdaptiveProgressRing(),
                                        )
                                      : AdaptiveIconButton(
                                          onPressed: () {
                                            GetIt.I<MediaPlayer>()
                                                    .player
                                                    .playing
                                                ? GetIt.I<MediaPlayer>()
                                                    .player
                                                    .pause()
                                                : GetIt.I<MediaPlayer>()
                                                    .player
                                                    .play();
                                          },
                                          icon: Icon(
                                            buttonState ==
                                                    ButtonState.playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: 30, // Slightly smaller play button
                                            color: Colors.white,
                                          ),
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
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
        });
  }
}