import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../../services/library_aggregation.dart';
import '../../../services/media_player.dart';
import '../../../utils/song_thumbnail.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `LibrarySongsScreen` / `LibraryAlbumsScreen` /
/// `LibraryArtistsScreen`: three tabs over the locally stored songs.
class LibraryCollectionsPage extends StatefulWidget {
  const LibraryCollectionsPage({super.key, required this.initialTab});
  final int initialTab; // 0 songs, 1 albums, 2 artists

  @override
  State<LibraryCollectionsPage> createState() => _LibraryCollectionsPageState();
}

class _LibraryCollectionsPageState extends State<LibraryCollectionsPage> {
  int _tab = 0;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<dynamic> _rawSongs() {
    final songs = <dynamic>[];
    for (final boxName in ['FAVOURITES', 'SONG_HISTORY']) {
      if (Hive.isBoxOpen(boxName)) {
        songs.addAll(Hive.box(boxName).values.whereType<Map>());
      }
    }
    return songs;
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Songs', 'Albums', 'Artists'];
    final raw = _rawSongs();
    final allSongs = LibraryAggregation.songList(raw);
    final albums = LibraryAggregation.albums(raw);
    final artists = LibraryAggregation.artists(raw);

    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: Text('Library · ${titles[_tab]}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search local library',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(titles[i]),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('FAVOURITES').listenable(),
              builder: (context, _, __) {
                final q = _search.text;
                if (_tab == 0) {
                  final items = LibraryAggregation.filter(allSongs, q);
                  return _songList(items);
                } else if (_tab == 1) {
                  final items = LibraryAggregation.filter(albums, q);
                  return _collectionList(items, isAlbum: true);
                } else {
                  final items = LibraryAggregation.filter(artists, q);
                  return _collectionList(items, isAlbum: false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _songList(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text('No songs in your library yet'));
    }
    final player = context.read<MediaPlayer>();
    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final song = songs[i];
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
    );
  }

  Widget _collectionList(List<Map<String, dynamic>> items,
      {required bool isAlbum}) {
    if (items.isEmpty) {
      return Center(
          child: Text(isAlbum ? 'No albums yet' : 'No artists yet'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = items[i];
        final songs = (item['songs'] as List).cast<Map<String, dynamic>>();
        return ListTile(
          leading: Icon(isAlbum ? Icons.album : Icons.person,
              size: 40),
          title: Text(item['name']?.toString() ?? 'Unknown'),
          subtitle: Text('${songs.length} songs'),
          onTap: () => context.go(
            '/saved/library_song_list',
            extra: {'songs': songs, 'title': item['name']?.toString()},
          ),
        );
      },
    );
  }
}

