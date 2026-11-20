import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `ListeningSummaryScreen.kt`: aggregates the local
/// playback history into top artists / top songs / totals. No network needed.
class ListeningSummaryPage extends StatelessWidget {
  const ListeningSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Listening Summary')),
      body: ValueListenableBuilder<Box>(
        valueListenable: Hive.box('SONG_HISTORY').listenable(),
        builder: (context, box, _) {
          final songs = box.values.whereType<Map>().toList();
          final artistCounts = <String, int>{};
          final songCounts = <String, int>{};
          final titles = <String, String>{};
          for (final song in songs) {
            final title = song['title']?.toString() ?? 'Unknown';
            final id = song['videoId']?.toString() ?? title;
            titles[id] = title;
            songCounts[id] = (songCounts[id] ?? 0) + 1;
            final artists = song['artists'];
            if (artists is List) {
              for (final a in artists) {
                if (a is Map) {
                  final name = a['name']?.toString();
                  if (name != null) {
                    artistCounts[name] = (artistCounts[name] ?? 0) + 1;
                  }
                } else if (a is String) {
                  artistCounts[a] = (artistCounts[a] ?? 0) + 1;
                }
              }
            }
          }
          final topArtists = artistCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topSongs = songCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          if (songs.isEmpty) {
            return const Center(
              child: Text('No listening history yet. Play some songs!'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(songs.length.toString(), 'Plays'),
                      _stat(artistCounts.length.toString(), 'Artists'),
                      _stat(songCounts.length.toString(), 'Songs'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Top artists',
                  style: Theme.of(context).textTheme.titleLarge),
              ...topArtists.take(10).map(
                    (e) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(e.key),
                      trailing: Text('${e.value}'),
                    ),
                  ),
              const SizedBox(height: 12),
              Text('Top songs', style: Theme.of(context).textTheme.titleLarge),
              ...topSongs.take(10).map(
                    (e) => ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(titles[e.key] ?? e.key),
                      trailing: Text('${e.value}'),
                    ),
                  ),
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
