import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Real port of Android `wrapped` ("Your year in sound"): a local recap
/// computed from playback history — top artists, top songs and listening
/// months. Requires no network and no login.
class WrappedPage extends StatelessWidget {
  const WrappedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Echo Wrapped')),
      body: ValueListenableBuilder<Box>(
        valueListenable: Hive.box('SONG_HISTORY').listenable(),
        builder: (context, box, _) {
          final songs = box.values.whereType<Map>().toList();
          if (songs.isEmpty) {
            return const Center(
              child: Text('No listening history yet. Play some songs!'),
            );
          }

          final artists = <String, int>{};
          final titles = <String, String>{};
          final counts = <String, int>{};
          final months = <int, int>{};
          for (final s in songs) {
            final id = s['videoId']?.toString() ?? s['title']?.toString() ?? '?';
            titles[id] = s['title']?.toString() ?? 'Unknown';
            counts[id] = (counts[id] ?? 0) + 1;
            final list = s['artists'];
            if (list is List) {
              for (final a in list) {
                final name = a is Map ? a['name']?.toString() : a?.toString();
                if (name != null) artists[name] = (artists[name] ?? 0) + 1;
              }
            }
            final ts = s['updatedAt'];
            if (ts is num && ts > 0) {
              final month = DateTime.fromMillisecondsSinceEpoch(ts.toInt()).month;
              months[month] = (months[month] ?? 0) + 1;
            }
          }
          final topArtist = artists.entries.isEmpty
              ? null
              : (artists.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
          final topSong = (counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Your year in sound',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _heroCard(theme, topArtist?.key ?? '—', 'Top artist',
                  Icons.person, '${topArtist?.value ?? 0} plays'),
              _heroCard(theme, titles[topSong.key] ?? topSong.key, 'Top song',
                  Icons.music_note, '${topSong.value} plays'),
              _heroCard(theme, '${songs.length}', 'Total plays',
                  Icons.play_circle, '${artists.length} artists'),
              const SizedBox(height: 20),
              Text('Listening by month',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ...() {
                final entries = months.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                final max = months.values.reduce((a, b) => a > b ? a : b);
                return entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text(_monthName(e.key))),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: max == 0 ? 0 : e.value / max,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${e.value}'),
                        ],
                      ),
                    ));
              }(),
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  Widget _heroCard(
      ThemeData theme, String value, String label, IconData icon, String sub) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Text('$label · $sub'),
      ),
    );
  }

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][(m - 1).clamp(0, 11)];
}
