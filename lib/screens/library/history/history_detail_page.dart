import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../../services/history_detail.dart';
import '../../../services/media_player.dart';
import '../../../utils/song_thumbnail.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `DetailedListeningHistoryScreen.kt`: history entries
/// grouped by day with total replay counts, from the local SONG_HISTORY box.
class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<MediaPlayer>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Listening history details')),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('SONG_HISTORY').listenable(),
        builder: (context, box, _) {
          final entries = box.values.toList();
          if (entries.isEmpty) {
            return const Center(child: Text('No listening history yet'));
          }
          final grouped = HistoryDetail.groupByDay(entries);
          final total = HistoryDetail.totalPlays(entries);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Total plays: $total',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(entry.key,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final song in entry.value)
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SongThumbnail(song: song, width: 44, height: 44),
                    ),
                    title: Text(song['title']?.toString() ?? 'Unknown'),
                    subtitle: Text('${song['plays'] ?? 1} plays'),
                    onTap: () => player.playSong(song),
                  ),
              ],
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }
}
