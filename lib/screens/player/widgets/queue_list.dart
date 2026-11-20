import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/queue_filter.dart';
import 'package:Echo/utils/song_thumbnail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Desktop port of the queue sheet (`ui/player/Queue.kt`) with the Android
/// `QueueExt` / `RadioQueuePageFilter` features: search filtering and
/// duplicate removal, plus reordering and swipe-to-remove.
class QueueList extends StatefulWidget {
  const QueueList({super.key});

  @override
  State<QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  final _search = TextEditingController();
  bool _hideDuplicates = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
                var sequence = snapshot.data?.sequence ?? [];
                final currentIndex = snapshot.data?.currentIndex ?? 0;

                // Android QueueExt: remove duplicates / filter by query.
                if (_hideDuplicates) {
                  sequence = QueueFilter.dedupe(
                    sequence,
                    (s) => s.tag?.id ?? '',
                  );
                }
                if (_search.text.trim().isNotEmpty) {
                  sequence = QueueFilter.search(
                    sequence,
                    _search.text,
                    titleOf: (s) => (s.tag as MediaItem?)?.title ?? '',
                    artistOf: (s) => (s.tag as MediaItem?)?.artist ?? '',
                  );
                }

                return Column(
                  children: [
                    _QueueHeader(
                      count: sequence.length,
                      player: player,
                      search: _search,
                      hideDuplicates: _hideDuplicates,
                      onToggleDuplicates: () => setState(
                          () => _hideDuplicates = !_hideDuplicates),
                      onSearchChanged: (_) => setState(() {}),
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
  const _QueueHeader({
    required this.count,
    required this.player,
    required this.search,
    required this.hideDuplicates,
    required this.onToggleDuplicates,
    required this.onSearchChanged,
  });

  final int count;
  final AudioPlayer player;
  final TextEditingController search;
  final bool hideDuplicates;
  final VoidCallback onToggleDuplicates;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Queue • $count',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Hide duplicates',
                isSelected: hideDuplicates,
                onPressed: onToggleDuplicates,
                icon: const Icon(Icons.filter_alt_off),
                color: hideDuplicates ? colorScheme.primary : null,
              ),
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
          TextField(
            controller: search,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Filter queue…',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
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

    return ListTile(
      selected: isCurrent,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          if (song.extras?['thumbnails'] is List &&
              (song.extras!['thumbnails'] as List).isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SongThumbnail(
                song: Map<String, dynamic>.from(song.extras!),
                width: 44,
                height: 44,
              ),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? colorScheme.primary : null,
          fontWeight: isCurrent ? FontWeight.bold : null,
        ),
      ),
      subtitle: song.artist != null
          ? Text(song.artist!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        tooltip: 'Remove from queue',
        onPressed: () => player.removeAudioSourceAt(index),
      ),
      onTap: () => player.seek(Duration.zero, index: index),
    );
  }
}
