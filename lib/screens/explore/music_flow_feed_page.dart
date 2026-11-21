import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/motion_tokens.dart';
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

  static const _palette = <Color>[
    Color(0xFF2B1B4D),
    Color(0xFF123B4A),
    Color(0xFF4A1F35),
    Color(0xFF1F3A24),
  ];

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
      if (_songs.isNotEmpty) await mp.playAll(_songs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
    final accent = _palette[_current % _palette.length];
    return Scaffold(
      body: AnimatedContainer(
        duration: MotionTokens.section,
        curve: MotionTokens.standard,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, const Color(0xFF0B0B10)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white70),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Could not load Music Flow: $_error',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white)),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _songs.isEmpty
                            ? const Center(
                                child: Text('No tracks available',
                                    style: TextStyle(color: Colors.white70)))
                            : PageView.builder(
                                controller: _controller,
                                scrollDirection: Axis.vertical,
                                itemCount: _songs.length,
                                onPageChanged: _onChanged,
                                itemBuilder: (context, i) =>
                                    _songPage(_songs[i], i),
                              ),
              ),
              Positioned(
                top: 8,
                left: 12,
                child: IconButton(
                  tooltip: 'Indietro',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  // go_router owns this route: Navigator.pop could land on a
                  // blank screen when the page was opened with context.go().
                  onPressed: () => context.pop(),
                ),
              ),
              Positioned(
                top: 22,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    'MUSIC FLOW',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              if (_songs.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _songs.length.clamp(0, 12),
                      (i) => AnimatedContainer(
                        duration: MotionTokens.micro,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        width: i == _current % 12 ? 8 : 4,
                        height: i == _current % 12 ? 18 : 4,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: i == _current % 12 ? 0.9 : 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_songs.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.keyboard_arrow_up,
                            color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text('Scorri per il prossimo brano',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songPage(Map<String, dynamic> song, int index) {
    final title = song['title']?.toString() ?? 'Unknown';
    final artists = (song['artists'] as List?)
            ?.map((a) => a['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ') ??
        '';
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(song['videoId'] ?? index),
        tween: Tween(begin: 0.92, end: 1),
        duration: MotionTokens.section,
        curve: MotionTokens.emphasized,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SongThumbnail(
                  song: song,
                  width: 280,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artists,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<ButtonState>(
              valueListenable: GetIt.I<MediaPlayer>().buttonState,
              builder: (context, state, _) {
                final playing = state == ButtonState.playing;
                return FloatingActionButton(
                  heroTag: 'flow-play-$index',
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    final mp = GetIt.I<MediaPlayer>();
                    if (mp.player.playing) {
                      await mp.player.pause();
                    } else {
                      await mp.player.play();
                    }
                  },
                  child: Icon(playing ? Icons.pause : Icons.play_arrow),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
