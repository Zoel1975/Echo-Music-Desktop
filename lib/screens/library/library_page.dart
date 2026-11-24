import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/utils/internet_guard.dart';
import 'package:Echo/utils/playlist_thumbnail.dart';

import '../../../../generated/l10n.dart';
import '../../../../services/library.dart';
import '../../../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../../../utils/bottom_modals.dart';
import '../../../../themes/text_styles.dart';
import 'cubit/library_cubit.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryCubit(sl<LibraryService>())..loadLibrary(),
      child: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          return InternetGuard(
            child: Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).Saved, style: appBarTitleStyle()),
                centerTitle: true,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () {
                      Modals.showImportplaylistModal(context);
                    },
                    icon: const Icon(
                      Icons.import_export_outlined,
                      size: 25,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Modals.showCreateplaylistModal(context);
                    },
                    icon: const Icon(
                      Icons.add,
                      size: 25,
                    ),
                  ),
                ],
              ),
              body: switch (state) {
                LibraryLoading() => const Center(child: AdaptiveProgressRing()),
                LibraryError(:final message) => Center(child: Text(message)),
                LibraryLoaded(
                  :final playlists,
                  :final favouritesCount,
                  :final downloadsCount,
                  :final historyCount
                ) =>
                  _LibraryBody(
                    playlists: playlists,
                    favouritesCount: favouritesCount,
                    downloadsCount: downloadsCount,
                    historyCount: historyCount,
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody(
      {required this.playlists,
      this.favouritesCount = 0,
      this.downloadsCount = 0,
      this.historyCount = 0});

  final Map playlists;
  final int favouritesCount;
  final int downloadsCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    // Collect all items into a list
    final List<Map<String, dynamic>> gridItems = [];

    // Signed-in YouTube Music library (real playlists/songs/albums/artists).
    gridItems.add({
      'title': 'YouTube Music library',
      'subtitle': 'Your playlists, liked songs, albums & artists',
      'icon': Icons.cloud_done,
      'onTap': () => context.push('/ytm_library'),
    });

    // Cloud library synced from Jellyfin / Navidrome when enabled.
    if (GetIt.I<SettingsManager>().extra<bool>('cloudSync', false)) {
      final cached = Hive.isBoxOpen('CLOUD_LIBRARY')
          ? Hive.box('CLOUD_LIBRARY').get('songs')
          : null;
      final count = cached is List ? cached.length : 0;
      gridItems.add({
        'title': 'Cloud library',
        'subtitle': '$count brani sincronizzati',
        'icon': Icons.cloud_sync,
        'onTap': () {
          final songs = cached is List ? cached : const [];
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cloud library'),
              content: SizedBox(
                width: 320,
                child: songs.isEmpty
                    ? const Text('Nessun brano sincronizzato')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: songs.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(songs[i]['title']?.toString() ?? ''),
                          subtitle: Text(songs[i]['artist']?.toString() ?? ''),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'))
              ],
            ),
          );
        },
      });
    }

    // Static Items — Android's "Show Liked / Downloaded playlist" toggles.
    final librarySettings = GetIt.I<SettingsManager>();
    if (librarySettings.showLikedPlaylist) {
      gridItems.add({
        'title': S.of(context).Favourites,
        'subtitle': S.of(context).nSongs(favouritesCount),
        'icon': AdaptiveIcons.heart_fill,
        'onTap': () => context.push('/saved/favourites_page'),
      });
    }

    if (librarySettings.showDownloadedPlaylist) {
      gridItems.add({
        'title': S.of(context).Downloads,
        'subtitle': S.of(context).nSongs(downloadsCount),
        'icon': AdaptiveIcons.download,
        'onTap': () => context.push('/saved/downloads_page'),
      });
    }

    gridItems.add({
      'title': S.of(context).History,
      'subtitle': S.of(context).nSongs(historyCount),
      'icon': Icons.history,
      'onTap': () => context.push('/saved/history_page'),
    });

    // Android LibrarySongs/Albums/Artists screens — aggregate local songs.
    gridItems.add({
      'title': 'Local songs',
      'subtitle': 'Scan and play your own audio files',
      'icon': Icons.folder_special,
      'onTap': () => context.push('/saved/local_songs'),
    });
    gridItems.add({
      'title': 'Songs',
      'subtitle': 'All songs in your library',
      'icon': Icons.music_note,
      'onTap': () => context.push('/saved/library_songs', extra: 0),
    });
    gridItems.add({
      'title': 'Albums',
      'subtitle': 'Browse by album',
      'icon': Icons.album,
      'onTap': () => context.push('/saved/library_songs', extra: 1),
    });
    gridItems.add({
      'title': 'Artists',
      'subtitle': 'Browse by artist',
      'icon': Icons.person,
      'onTap': () => context.push('/saved/library_songs', extra: 2),
    });
    gridItems.add({
      'title': 'Podcasts',
      'subtitle': 'Podcast e serie YouTube Music',
      'icon': Icons.podcasts,
      'onTap': () => context.push('/podcasts'),
    });

    // Playlists
    final sortedPlaylists = SplayTreeMap.from(playlists);
    for (var entry in sortedPlaylists.entries) {
      if (entry.value == null) continue;
      final key = entry.key;
      final item = entry.value;

      gridItems.add({
        'title': item['title'],
        'subtitle': (item['songs'] != null || item['isPredefined'])
            ? (item['isPredefined'] == true
                ? item['subtitle']
                : S.of(context).nSongs(item['songs'].length))
            : '',
        'playlist_item': item,
        'playlist_key': key,
        'onTap': () {
          if (item['isPredefined'] == true) {
            context.push(
              '/browse',
              extra: {
                'endpoint': item['endpoint'].cast<String, dynamic>(),
              },
            );
          } else {
            context.push(
              '/saved/playlist_details',
              extra: {
                'playlistkey': key,
              },
            );
          }
        },
        'onSecondaryTap': () {
           if (item['videoId'] == null && item['playlistId'] != null) {
              Modals.showPlaylistBottomModal(context, item);
            } else if (item['isPredefined'] == false) {
              Modals.showPlaylistBottomModal(
                context,
                {...item, 'playlistId': key},
              );
            }
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: switch (
                GetIt.I<SettingsManager>().extra<String>('gridCellSize', 'Medium')) {
              'Small' => 150.0,
              'Large' => 260.0,
              _ => 200.0,
            },
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: gridItems.length,
          itemBuilder: (context, index) {
            final item = gridItems[index];
            return _LibraryGridCard(item: item);
          },
        );
      },
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _LibraryGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AdaptiveInkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item['onTap'],
      onSecondaryTap: item['onSecondaryTap'], 
      onLongPress: item['onSecondaryTap'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildImage(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (item['subtitle'] != null && item['subtitle'].toString().isNotEmpty)
             Text(
              item['subtitle'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (item['icon'] != null) {
      return Icon(
        item['icon'],
        size: 40,
        color: Theme.of(context).iconTheme.color,
      );
    }
    
    // Playlist logic
    final playlistItem = item['playlist_item'];
    if (playlistItem != null) {
       if (playlistItem['isPredefined'] == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: playlistItem['thumbnails']
                .first['url']
                .replaceAll('w540-h225', 'w512-h512'), // Larger image for grid
            fit: BoxFit.cover,
          ),
        );
      }

      if (playlistItem['songs'] != null && playlistItem['songs'].isNotEmpty) {
        return PlaylistThumbnail(
          playslist: playlistItem['songs'],
          size: 200, // Larger size
          radius: 12,
        );
      }
    }

    return const Icon(CupertinoIcons.music_note_list, size: 40);
  }
}