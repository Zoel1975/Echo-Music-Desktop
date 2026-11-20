import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../services/library_aggregation.dart';
import '../../services/media_player.dart';
import '../../utils/song_thumbnail.dart';
import '../../../core/widgets/back_button.dart';

/// Real port of Android `LocalSearchScreen`: searches locally stored songs
/// (favourites, history, playlists) without a network request.
class LocalSearchPage extends StatefulWidget {
  const LocalSearchPage({super.key});

  @override
  State<LocalSearchPage> createState() => _LocalSearchPageState();
}

class _LocalSearchPageState extends State<LocalSearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _sources() {
    final songs = <dynamic>[];
    for (final boxName in ['FAVOURITES', 'SONG_HISTORY', 'LIBRARY']) {
      if (!Hive.isBoxOpen(boxName)) continue;
      for (final value in Hive.box(boxName).values) {
        if (value is Map) {
          if (value['songs'] is Iterable) {
            songs.addAll((value['songs'] as Iterable));
          } else {
            songs.add(value);
          }
        }
      }
    }
    return LibraryAggregation.songList(songs);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<MediaPlayer>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Local search')),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('FAVOURITES').listenable(),
        builder: (context, _, __) {
          final all = _sources();
          final results = LibraryAggregation.filter(all, _controller.text);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search your library',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${results.length} local results',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('No matching local songs'))
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final song = results[i];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child:
                                  SongThumbnail(song: song, width: 44, height: 44),
                            ),
                            title: Text(song['title']?.toString() ?? 'Unknown'),
                            subtitle:
                                Text(LibraryAggregation.artistName(song) ?? ''),
                            onTap: () => player.playSong(song),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
