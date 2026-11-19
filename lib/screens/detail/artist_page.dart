import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'package:Echo/core/utils/service_locator.dart';
import 'package:Echo/core/widgets/section_item.dart';
import 'package:Echo/screens/browse/cubit/browse_cubit.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/utils/internet_guard.dart';
import 'package:Echo/utils/playable.dart';

/// Desktop port of `ui/screens/artist/ArtistScreen.kt`.
///
/// Header + Play button + songs section + album sections (via `SectionItem`;
/// album taps navigate to `/album`). "Follow artist", videos, related
/// content and other tabs are out of scope for this port.
class ArtistPage extends StatelessWidget {
  const ArtistPage({required this.browseId});

  final String browseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BrowseCubit(sl(), endpoint: {'browseId': browseId})..fetch(),
      child: const _ArtistPage(),
    );
  }
}

class _ArtistPage extends StatefulWidget {
  const _ArtistPage();

  @override
  State<_ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<_ArtistPage> {
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
            List<Map<String, dynamic>>? songs;
            for (final section in state.sections) {
              final contents = (section['contents'] as List?) ?? const [];
              if (contents
                  .any((c) => (c as Map?)?['type'] == 'SONG' || c?['videoId'] != null)) {
                songs = toPlaySongs(contents);
                break;
              }
            }
            final mediaPlayer = context.read<MediaPlayer>();
            return Scaffold(
              body: InternetGuard(
                onInternetRestored: () => context.read<BrowseCubit>().fetch(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ArtistHeader(header: header),
                    if (songs != null && songs.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => mediaPlayer.playAll(songs!),
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Play ${songs.length}'),
                      ),
                    if (songs != null && songs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final section in state.sections)
                        if ((section['contents'] as List?)?.isNotEmpty == true)
                          SectionItem(section: section),
                    ],
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({required this.header});

  final Map<dynamic, dynamic> header;

  @override
  Widget build(BuildContext context) {
    final thumbnails = (header['thumbnails'] as List?) ?? const [];
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
              errorWidget: (_, __, ___) => const Icon(Icons.music_note),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          header['title']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        if (header['subtitle'] != null) ...[
          const SizedBox(height: 4),
          Text(
            header['subtitle']?.toString() ?? '',
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 12),
          ),
        ],
      ],
    );
  }
}
