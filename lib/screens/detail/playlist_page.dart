import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:Echo/core/widgets/back_button.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/stem_separation_queue.dart';
import 'package:Echo/utils/playable.dart';
import 'package:Echo/utils/safe_cast.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Desktop port of `ui/screens/playlist/OnlinePlaylistScreen.kt` +
/// `BottomPlaylistScreen.kt`: an online playlist with its song list,
/// Play / Shuffle buttons and the same add/remove edits as the mobile app.
class OnlinePlaylistPage extends StatefulWidget {
  const OnlinePlaylistPage({required this.playlistId});

  final String playlistId;

  static int? get songCount => _OnlinePlaylistPageState.lastSongCount;
  static int? get uniqueCount => _OnlinePlaylistPageState.lastUniqueCount;
  static bool? get isLoading => _OnlinePlaylistPageState.lastLoading;
  static List<Map<String, dynamic>>? get songs => _OnlinePlaylistPageState.lastSongs;

  @override
  State<OnlinePlaylistPage> createState() => _OnlinePlaylistPageState();
}

class _OnlinePlaylistPageState extends State<OnlinePlaylistPage> {
  /// Live diagnostics for the runtime probe.
  static int? lastSongCount;
  static int? lastUniqueCount;
  static bool? lastLoading;
  static List<Map<String, dynamic>>? lastSongs;

  final _mediaPlayer = GetIt.I<MediaPlayer>();
  final _ytMusic = GetIt.I<YTMusic>();

  List<Map<String, dynamic>> _songs = const [];
  String _title = 'Online Playlist';
  List<Map<String, dynamic>> _thumbnails = const [];
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
      final response =
          await _ytMusic.browse(body: {'browseId': widget.playlistId});
      final header = response['header'] ?? {};
      if (mounted) {
        setState(() {
          _title = (header['title'] as String?) ?? 'Online Playlist';
          _thumbnails = safeMapList(header['thumbnails']);
        });
      }

      // Show the first batch (100 songs) immediately; the remaining 7-song
      // continuation pages are appended as they arrive.
      final raw = <dynamic>[];
      final songs = await _ytMusic.getPlaylistSongs(
        widget.playlistId,
        onBatch: (batch) {
          raw.addAll(batch);
          if (mounted) setState(() => _songs = toPlaySongs(raw));
        },
      );
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
    final songs = shuffle
        ? (List<Map<String, dynamic>>.from(_songs)..shuffle())
        : _songs;
    await _mediaPlayer.playAll(songs);
  }

  /// Mirrors Android's SongMenu "Remove from playlist".
  Future<void> _remove(Map<String, dynamic> song) async {
    final videoId = song['videoId']?.toString() ?? '';
    final setVideoId = song['setVideoId']?.toString() ?? '';
    if (videoId.isEmpty || setVideoId.isEmpty) {
      _showMessage('Impossibile rimuovere: identificativo brano mancante.');
      return;
    }
    try {
      await _ytMusic.removeFromPlaylist(widget.playlistId, videoId, setVideoId);
      if (mounted) _showMessage('Brano rimosso dalla playlist');
      await _load();
    } catch (e) {
      if (mounted) _showMessage('Rimozione non riuscita: $e');
    }
  }

  Future<void> _separateAll() async {
    final queue = StemSeparationQueue.instance;
    if (queue.playlistBusy) {
      _showMessage('Separazione già in corso');
      return;
    }
    if (_songs.isEmpty) {
      _showMessage('Nessun brano nella playlist');
      return;
    }
    _showMessage('Separazione di ${_songs.length} brani avviata…');
    await queue.enqueuePlaylist(_songs);
    if (!mounted) return;
    final errors = queue.playlistErrors;
    if (errors.isEmpty) {
      _showMessage('Stem pronti: ${queue.playlistSeparated} separati, '
          '${queue.playlistSkipped} già presenti');
    } else {
      _showMessage('Stem: ${queue.playlistSeparated} separati, '
          '${errors.length} errori — ${errors.first}');
    }
  }

  Future<void> _addSongs() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddToPlaylistDialog(playlistId: widget.playlistId),
    );
    if (added == true && mounted) {
      _showMessage('Brani aggiunti alla playlist');
      await _load();
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    _OnlinePlaylistPageState.lastSongCount = _songs.length;
    _OnlinePlaylistPageState.lastUniqueCount =
        _songs.map((s) => s['videoId']).toSet().length;
    _OnlinePlaylistPageState.lastLoading = _isLoading;
    _OnlinePlaylistPageState.lastSongs = _songs;
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Separate all tracks',
            icon: const Icon(Icons.call_split),
            onPressed: _separateAll,
          ),
          IconButton(
            tooltip: 'Aggiungi brani',
            icon: const Icon(Icons.add),
            onPressed: _addSongs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSongs,
        tooltip: 'Aggiungi brani',
        child: const Icon(Icons.playlist_add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlaylistHeader(
            title: _title,
            thumbnails: _thumbnails,
            songs: _songs,
            onPlay: () => _play(),
            onShuffle: () => _play(shuffle: true),
          ),
          AnimatedBuilder(
            animation: StemSeparationQueue.instance,
            builder: (context, _) {
              final queue = StemSeparationQueue.instance;
              if (!queue.playlistBusy) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Text('Separating stems ${queue.playlistDone}/'
                        '${queue.playlistTotal} · '
                        '${queue.playlistSeparated} done, '
                        '${queue.playlistErrors.length} failed'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: queue.playlistProgress),
                  ],
                ),
              );
            },
          ),
          if (_isLoading && _songs.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_isLoading && _songs.isEmpty)
            const Center(child: CircularProgressIndicator()),
          ..._songs.asMap().entries.map(
                (entry) => _PlaylistRow(
                  song: entry.value,
                  index: entry.key,
                  songs: _songs,
                  onRemove: () => _remove(entry.value),
                ),
              ),
        ],
      ),
    );
  }
}

/// Android's AddToPlaylistDialog, flipped around: search songs and push them
/// into the playlist currently open.
class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({super.key, required this.playlistId});
  final String playlistId;

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final _controller = TextEditingController();
  final _yt = GetIt.I<YTMusic>();
  List<Map<String, dynamic>> _results = const [];
  final Set<String> _added = {};
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final response = await _yt.search(query, filter: 'songs', limit: 20);
      final sections = safeMapList(response['sections']);
      final songs = <Map<String, dynamic>>[];
      for (final section in sections) {
        songs.addAll(safeMapList(section['contents']));
      }
      if (!mounted) return;
      setState(() {
        _results = toPlaySongs(songs);
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  Future<void> _add(Map<String, dynamic> song) async {
    final id = song['videoId']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await _yt.addToPlaylist(widget.playlistId, id);
      if (mounted) setState(() => _added.add(id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aggiunta non riuscita: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiungi brani alla playlist'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Cerca un brano o un artista',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_searching)
              const LinearProgressIndicator()
            else
              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text('Cerca un brano per aggiungerlo.'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final song = _results[i];
                          final id = song['videoId']?.toString() ?? '';
                          final done = _added.contains(id);
                          return ListTile(
                            title: Text(song['title']?.toString() ?? ''),
                            subtitle: Text(song['subtitle']?.toString() ?? ''),
                            trailing: IconButton(
                              tooltip: done ? 'Aggiunto' : 'Aggiungi',
                              icon: Icon(done
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline),
                              onPressed: done ? null : () => _add(song),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _added.isNotEmpty),
          child: const Text('Fatto'),
        ),
      ],
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
    if (songs.isNotEmpty) return safeMapList(songs.first['thumbnails']);
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
  const _PlaylistRow({
    required this.song,
    required this.index,
    required this.songs,
    required this.onRemove,
  });

  final Map<String, dynamic> song;
  final int index;
  final List<Map<String, dynamic>> songs;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final thumbnails = safeMapList(song['thumbnails']);
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
      // Android: tapping a track plays it with the whole playlist as its
      // queue, starting at the tapped index - never a one-song queue.
      onTap: () => GetIt.I<MediaPlayer>().playAll(songs, index: index),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'remove') unawaited(onRemove());
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'remove',
            child: Row(children: [
              Icon(Icons.remove_circle_outline),
              SizedBox(width: 8),
              Text('Rimuovi dalla playlist'),
            ]),
          ),
        ],
      ),
    );
  }
}
