import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:Echo/services/media_player.dart';
import 'package:Echo/utils/playable.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Desktop port of `ui/screens/playlist/OnlinePlaylistScreen.kt` +
/// `BottomPlaylistScreen.kt`: an online playlist with its song list and
/// Play / Shuffle buttons.
///
/// Offline playlists live in `LibraryService`/`PlaylistDetailsPage` — this
/// page only serves online playlists (`VL...`).
class OnlinePlaylistPage extends StatefulWidget {
  const OnlinePlaylistPage({required this.playlistId});

  final String playlistId;

  @override
  State<OnlinePlaylistPage> createState() => _OnlinePlaylistPageState();
}

class _OnlinePlaylistPageState extends State<OnlinePlaylistPage> {
  final _mediaPlayer = GetIt.I<MediaPlayer>();
  final _ytMusic = GetIt.I<YTMusic>();

  List<Map<String, dynamic>> _songs = const [];
  String _title = 'Online Playlist';
  List<Map<String, dynamic>>? _thumbnails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _ytMusic.browse(body: {'browseId': widget.playlistId});
      final header = response['header'] ?? {};
      if (mounted) {
        setState(() {
          _title = (header['title'] as String?) ?? 'Online Playlist';
          _thumbnails = header['thumbnails'] as List<Map<String, dynamic>>?;
        });
      }

      final songs = await _ytMusic.getPlaylistSongs(widget.playlistId);
      if (mounted) {
        setState(() {
          _songs = toPlaySongs(songs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _songs = const [];
          _isLoading = false;
          _error = 'Unable to load playlist: $e';
        });
      }
    }
  }

  Future<void> _play({bool shuffle = false}) async {
    if (_songs.isEmpty) return;
    List<Map<String, dynamic>> songs;
    if (shuffle) {
      songs = List<Map<String, dynamic>>.from(_songs)..shuffle();
    } else {
      songs = _songs;
    }
    await _mediaPlayer.playAll(songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlaylistHeader(
            title: _title,
            thumbnails: _thumbnails ?? const [],
            songs: _songs,
            onPlay: () => _play(),
            onShuffle: () => _play(shuffle: true),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_isLoading && _songs.isEmpty)
            const Center(child: CircularProgressIndicator()),
          for (final song in _songs)
            _PlaylistRow(song: song),
        ],
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.title,
    required this.thumbnails,
    required this.songs,
    required this.onPlay,
    required this.onShuffle,
  });

  final String title;
  final List<Map<String, dynamic>> thumbnails;
  final List<Map<String, dynamic>> songs;
  final Future<void> Function() onPlay;
  final VoidCallback onShuffle;

  List<Map<String, dynamic>> get _thumb {
    if (thumbnails.isNotEmpty) return thumbnails;
    if (songs.isNotEmpty) {
      final List? thumbs = songs.first['thumbnails'];
      return (thumbs as List<Map<String, dynamic>>?) ??
          const <Map<String, dynamic>>[];
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (thumb.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: thumb.first['url'] as String,
              width: 300,
              height: 300,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.queue_music),
            ),
          ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${songs.length} tracks',
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            IconButton(
              tooltip: 'Shuffle',
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.song});

  final Map<String, dynamic> song;

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final List<Map<String, dynamic>> thumbnails =
        song['thumbnails'] as List<Map<String, dynamic>>? ??
            const <Map<String, dynamic>>[];
    return ListTile(
      leading: thumbnails.isEmpty
          ? const Icon(Icons.music_note)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: thumbnails.first['url'] as String,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.music_note),
              ),
            ),
      title: Text(song['title'] as String? ?? '', maxLines: 1),
      subtitle: Text(song['subtitle'] as String? ?? '', maxLines: 1),
      onTap: () => mediaPlayer.playSong(Map<String, dynamic>.from(song)),
      trailing: const Icon(Icons.drag_handle),
    );
  }
}
