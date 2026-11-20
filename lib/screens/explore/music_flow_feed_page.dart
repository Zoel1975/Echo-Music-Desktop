import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/utils/service_locator.dart';
import '../../services/media_player.dart';
import '../../utils/playable.dart';
import '../../utils/song_thumbnail.dart';
import '../../ytmusic/ytmusic.dart';

/// Real desktop port of Android `MusicFlowScreen` (Resso-style vertical swipe
/// discovery): a full-screen vertical PageView fed by the InnerTube radio
/// ("next") queue. Swiping plays the focused track.
class MusicFlowFeedPage extends StatefulWidget {
  const MusicFlowFeedPage({super.key});

  @override
  State<MusicFlowFeedPage> createState() => _MusicFlowFeedPageState();
}

class _MusicFlowFeedPageState extends State<MusicFlowFeedPage> {
  final PageController _controller = PageController();
  final List<Map<String, dynamic>> _songs = [];
  bool _loading = true;
  String? _error;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mp = GetIt.I<MediaPlayer>();
      final songs = await sl<YTMusic>().getNextSongList(
        videoId: mp.currentSongNotifier.value?.id,
      );
      final playable = toPlaySongs(songs);
      if (!mounted) return;
      setState(() {
        _songs
          ..clear()
          ..addAll(playable);
        _loading = false;
      });
      if (_songs.isNotEmpty) {
        await mp.playAll(_songs);
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onChanged(int index) async {
    setState(() => _current = index);
    if (index >= 0 && index < _songs.length) {
      await GetIt.I<MediaPlayer>().playSong(_songs[index]);
    }
    if (index >= _songs.length - 3) await _loadMore();
  }

  Future<void> _loadMore() async {
    final last = _songs.isEmpty ? null : _songs.last['videoId'] as String?;
    try {
      final songs = await sl<YTMusic>().getNextSongList(videoId: last);
      final more = toPlaySongs(songs).where(
        (s) => !_songs.any((e) => e['videoId'] == s['videoId']),
      );
      if (mounted) setState(() => _songs.addAll(more));
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load Music Flow: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _songs.isEmpty
                  ? const Center(child: Text('No tracks available'))
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _controller,
                          scrollDirection: Axis.vertical,
                          itemCount: _songs.length,
                          onPageChanged: _onChanged,
                          itemBuilder: (context, i) {
                            final song = _songs[i];
                            return Container(
                              color: Colors.black,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SongThumbnail(
                                        song: song,
                                        width: 260,
                                        height: 260,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      song['title']?.toString() ?? 'Unknown',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (song['artists'] as List?)
                                              ?.map((a) => a['name'])
                                              .join(', ') ??
                                          '',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: 40,
                          left: 16,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned(
                          top: 44,
                          right: 16,
                          child: Text(
                            '${_current + 1}/${_songs.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
