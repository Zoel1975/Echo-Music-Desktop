import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/utils/song_thumbnail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Desktop port of the queue sheet (`ui/player/Queue.kt`).
///
/// Differences from the previous implementation:
///  * shuffling is available on every platform (it was gated to Android even
///    though `just_audio` implements shuffle in Dart);
///  * every key is scoped by index, so a queue that contains the same song
///    twice no longer produces duplicate `Dismissible` keys;
///  * reordering uses an explicit drag handle so it does not fight the
///    swipe-to-remove gesture (especially with a mouse);
///  * removal no longer also dismisses the widget, which used to leave stale
///    `Dismissible` widgets in the tree.
class QueueList extends StatelessWidget {
  const QueueList({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final player = mediaPlayer.player;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SafeArea(
            top: false,
            child: StreamBuilder(
              stream: mediaPlayer.currentTrackStream,
              builder: (context, snapshot) {
                final sequence = snapshot.data?.sequence ?? [];
                final currentIndex = snapshot.data?.currentIndex ?? 0;

                return Column(
                  children: [
                    _QueueHeader(
                      count: sequence.length,
                      player: player,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: sequence.isEmpty
                          ? const Center(child: Text('Queue is empty'))
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              itemCount: sequence.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (newIndex > oldIndex) newIndex -= 1;
                                await player.moveAudioSource(oldIndex, newIndex);
                              },
                              itemBuilder: (context, i) {
                                return QueueTile(
                                  key: ValueKey('queue-$i-${sequence[i].tag?.id}'),
                                  index: i,
                                  isCurrent: i == currentIndex,
                                  source: sequence[i],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.count, required this.player});

  final int count;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Text(
            'Queue • $count',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          StreamBuilder<bool>(
            stream: player.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final shuffle = snapshot.data ?? false;
              return IconButton(
                tooltip: S.of(context).Shuffle,
                isSelected: shuffle,
                onPressed: () => player.setShuffleModeEnabled(!shuffle),
                icon: const Icon(Icons.shuffle),
                color: shuffle ? colorScheme.primary : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class QueueTile extends StatelessWidget {
  final int index;
  final bool isCurrent;
  final IndexedAudioSource source;

  const QueueTile({
    super.key,
    required this.index,
    required this.isCurrent,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final player = GetIt.I<MediaPlayer>().player;
    final MediaItem? song = source.tag as MediaItem?;

    if (song == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-$index-${song.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.error,
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      // The queue is owned by the player, not by this list: remove the source
      // and let the stream rebuild. Returning false keeps the Dismissible from
      // being disposed twice ("dismissed widget still in the tree").
      confirmDismiss: (_) async {
        await player.removeAudioSourceAt(index);
        return false;
      },
      child: ListTile(
        selected: isCurrent,
        onTap: () => player.seek(Duration.zero, index: index),
        leading: ArtworkWidget(song: song, isCurrent: isCurrent),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          song.artist ?? song.album ?? song.extras?['subtitle'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_handle),
          ),
        ),
      ),
    );
  }
}

class ArtworkWidget extends StatelessWidget {
  final MediaItem song;
  final bool isCurrent;

  const ArtworkWidget({
    super.key,
    required this.song,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final double dp = MediaQuery.of(context).devicePixelRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SongThumbnail(
            song: song.extras!,
            dp: dp,
            height: 50,
            width: 50,
            fit: BoxFit.fill,
            errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 32),
          ),
          if (isCurrent)
            Container(
              height: 50,
              width: 50,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          if (isCurrent)
            const Positioned(
              width: 34,
              height: 34,
              left: 8,
              top: 8,
              child: Center(
                child: Icon(
                  Icons.music_note_outlined,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
