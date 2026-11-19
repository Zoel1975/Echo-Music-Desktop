import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/core/widgets/section_item.dart';
import 'package:Echo/screens/browse/cubit/browse_cubit.dart';
import 'package:Echo/services/library.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/utils/internet_guard.dart';
import 'package:Echo/utils/playable.dart';

/// Desktop port of `ui/screens/AlbumScreen.kt`.
///
/// Header + play + "Add to library" + the album's songs (`musicShelfRenderer`).
/// On Android the page also shows "Other versions" and "Releases for you" —
/// those are omitted from this port (see docs/PORTING_PLAN.md §9).
class AlbumPage extends StatelessWidget {
  const AlbumPage({required this.browseId});

  final String browseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BrowseCubit(sl(), endpoint: {'browseId': browseId})..fetch(),
      child: const _AlbumPage(),
    );
  }
}

class _AlbumPage extends StatefulWidget {
  const _AlbumPage();

  @override
  State<_AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<_AlbumPage> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BrowseCubit, BrowseState>(
      builder: (context, state) {
        switch (state) {
          case BrowseLoading():
            return const Scaffold(
                body: Center(child: LoadingIndicatorM3E()));
          case BrowseError():
            return Scaffold(body: Center(child: Text(state.message ?? '')));
          case BrowseSuccess():
            final header = state.header;
            Map<String, dynamic>? songsSection;
            for (final section in state.sections) {
              final contents = (section['contents'] as List?) ?? const [];
              if (contents.any(
                (c) => (c as Map?)?['type'] == 'SONG' || c?['videoId'] != null,
              )) {
                songsSection = section;
                break;
              }
            }
            final songs =
                toPlaySongs(songsSection?['contents'] ?? const <Map<String, dynamic>>[]);
            if (songsSection != null) {
              songsSection['viewType'] = 'SINGLE_COLUMN';
            }
            return Scaffold(
              body: InternetGuard(
                onInternetRestored: () => context.read<BrowseCubit>().fetch(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _AlbumHeader(header: header, songs: songs),
                    if (songsSection != null)
                      SectionItem(section: songsSection!),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

class _AlbumHeader extends StatefulWidget {
  const _AlbumHeader({required this.header, required this.songs});

  final Map<dynamic, dynamic> header;
  final List<Map<String, dynamic>> songs;

  @override
  State<_AlbumHeader> createState() => _AlbumHeaderState();
}

class _AlbumHeaderState extends State<_AlbumHeader> {
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    final playlistId = widget.header['playlistId'] as String?;
    _liked = playlistId != null &&
        context.read<LibraryService>().playlists[playlistId] != null;
  }

  void _toggleLike() {
    final playlistId = widget.header['playlistId'] as String?;
    if (playlistId == null) {
      return;
    }
    final library = context.read<LibraryService>();
    library.addToOrRemoveFromLibrary(Map<String, dynamic>.from(widget.header));
    setState(() => _liked = !_liked);
  }

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = context.read<MediaPlayer>();
    final header = widget.header;
    final thumbnails = (header['thumbnails'] as List?) ?? const [];
    final List artists = (header['artists'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (thumbnails.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: thumbnails.first['url'] as String,
              width: 260,
              height: 260,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 260,
                height: 260,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.music_note),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          header['title']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        if (artists.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < artists.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    final browseId = artists[i]['endpoint']?['browseId'];
                    if (browseId != null) {
                      context.go('/artist', extra: {'browseId': browseId});
                    }
                  },
                  child: Text(
                    artists[i]['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (header['subtitle'] != null) ...[
          const SizedBox(height: 4),
          Text(
            header['subtitle']?.toString() ?? '',
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => mediaPlayer.playAll(widget.songs),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            IconButton(
              tooltip: _liked ? 'Liked' : 'Add to library',
              onPressed: _toggleLike,
              icon: Icon(
                Icons.favorite,
                color: _liked ? Colors.red : Colors.grey,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
