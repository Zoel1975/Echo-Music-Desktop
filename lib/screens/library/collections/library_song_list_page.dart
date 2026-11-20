import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/media_player.dart';
import '../../../services/library_aggregation.dart';
import '../../../utils/song_thumbnail.dart';

/// Shows the songs of an album/artist tapped in Library Collections.
class LibrarySongListPage extends StatelessWidget {
  const LibrarySongListPage({super.key, required this.songs, this.title});
  final List<dynamic> songs;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final player = context.read<MediaPlayer>();
    final list = LibraryAggregation.songList(songs);
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Songs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play all',
            onPressed: () => player.playAll(list),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final song = list[i];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SongThumbnail(song: song, width: 44, height: 44),
            ),
            title: Text(song['title']?.toString() ?? 'Unknown'),
            subtitle: Text(LibraryAggregation.artistName(song) ?? ''),
            onTap: () => player.playSong(song),
          );
        },
      ),
    );
  }
}
