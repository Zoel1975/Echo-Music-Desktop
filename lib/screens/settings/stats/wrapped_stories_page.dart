import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/widgets/back_button.dart';
import '../../../../services/media_player.dart';

/// Port of Android `WrappedScreen.kt`: 9 Spotify-style animated slides built
/// from local listening history. No network, no login.
class WrappedStoriesPage extends StatefulWidget {
  const WrappedStoriesPage({super.key});

  @override
  State<WrappedStoriesPage> createState() => _WrappedStoriesPageState();
}

class WrappedTheme {
  const WrappedTheme({
    required this.background,
    required this.headline,
    required this.label,
    required this.body,
    required this.card,
  });

  final Color background;
  final Color headline;
  final Color label;
  final Color body;
  final Color card;
}

const wrappedThemes = <WrappedTheme>[
  WrappedTheme(
    background: Color(0xFF5925DC),
    headline: Colors.white,
    label: Color(0xFF00F5D4),
    body: Color(0xFFE9D5FF),
    card: Color(0xFF4318B0),
  ),
  WrappedTheme(
    background: Color(0xFFFFC700),
    headline: Color(0xFF0A0A0A),
    label: Color(0xFF1E293B),
    body: Color(0xFF1E293B),
    card: Color(0xFFE5B300),
  ),
  WrappedTheme(
    background: Color(0xFF025940),
    headline: Color(0xFF34D399),
    label: Color(0xFFA7F3D0),
    body: Color(0xFFE6FFFA),
    card: Color(0xFF034431),
  ),
  WrappedTheme(
    background: Color(0xFFE02424),
    headline: Color(0xFFFFDF00),
    label: Color(0xFFFFDF00),
    body: Colors.white,
    card: Color(0xFFB91C1C),
  ),
  WrappedTheme(
    background: Color(0xFF1E40AF),
    headline: Colors.white,
    label: Color(0xFF38BDF8),
    body: Color(0xFFDBEAFE),
    card: Color(0xFF1E3A8A),
  ),
  WrappedTheme(
    background: Color(0xFF4C1D95),
    headline: Color(0xFF00F5D4),
    label: Color(0xFF00F5D4),
    body: Color(0xFFF3E8FF),
    card: Color(0xFF3B0764),
  ),
  WrappedTheme(
    background: Color(0xFFEA580C),
    headline: Color(0xFFFFFBEB),
    label: Color(0xFFFEF3C7),
    body: Color(0xFFFFEDD5),
    card: Color(0xFFC2410C),
  ),
  WrappedTheme(
    background: Color(0xFF701A75),
    headline: Color(0xFFA3E635),
    label: Color(0xFFA3E635),
    body: Color(0xFFFDF4FF),
    card: Color(0xFF4A044E),
  ),
  WrappedTheme(
    background: Color(0xFF111111),
    headline: Colors.white,
    label: Color(0xFF1DB954),
    body: Color(0xFFDDDDDD),
    card: Color(0xFF1E1E1E),
  ),
];

class PlayStat {
  PlayStat(this.title, this.artist, this.count, this.videoId);

  final String title;
  final String artist;
  final int count;
  final String videoId;
}

class WrappedData {
  WrappedData({
    required this.totalMinutes,
    required this.uniqueSongs,
    required this.uniqueArtists,
    required this.topSongs,
    required this.topArtists,
    required this.months,
    required this.year,
  });

  final int totalMinutes;
  final int uniqueSongs;
  final int uniqueArtists;
  final List<PlayStat> topSongs;
  final List<PlayStat> topArtists;
  final Map<int, int> months;
  final int year;

  PlayStat? get topSong => topSongs.isEmpty ? null : topSongs.first;
  PlayStat? get topArtist => topArtists.isEmpty ? null : topArtists.first;

  String get persona {
    if (uniqueArtists > 120) return 'Eclectic Explorer';
    if (totalMinutes > 3000) return 'Devoted Listener';
    if (uniqueSongs < 30) return 'Loyal Replayer';
    return 'Curious Mixer';
  }

  static WrappedData fromHistory(List<Map> songs) {
    final songCounts = <String, int>{};
    final songTitles = <String, String>{};
    final songArtists = <String, String>{};
    final songIds = <String, String>{};
    final artistCounts = <String, int>{};
    final months = <int, int>{};
    var minutes = 0;

    for (final song in songs) {
      final id = song['videoId']?.toString() ?? song['title']?.toString() ?? '?';
      songCounts[id] = (songCounts[id] ?? 0) + 1;
      songTitles[id] = song['title']?.toString() ?? 'Unknown';
      final artists = song['artists'];
      final artist = artists is List && artists.isNotEmpty
          ? (artists.first is Map
              ? artists.first['name']?.toString()
              : artists.first?.toString()) ??
              'Various'
          : 'Various';
      songArtists[id] = artist;
      songIds[id] = id;
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      final duration = song['duration'];
      if (duration is num) {
        minutes += (duration > 10000 ? duration ~/ 60000 : duration ~/ 1000);
      }
      final ts = song['updatedAt'];
      if (ts is num && ts > 0) {
        final month = DateTime.fromMillisecondsSinceEpoch(ts.toInt()).month;
        months[month] = (months[month] ?? 0) + 1;
      }
    }

    List<PlayStat> top(Map<String, int> counts, bool songs) {
      final entries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(5).map((e) {
        return PlayStat(
          songs ? songTitles[e.key] ?? e.key : e.key,
          songs ? songArtists[e.key] ?? '' : '${e.value} plays',
          e.value,
          songs ? songIds[e.key] ?? e.key : e.key,
        );
      }).toList();
    }

    return WrappedData(
      totalMinutes: minutes,
      uniqueSongs: songCounts.length,
      uniqueArtists: artistCounts.length,
      topSongs: top(songCounts, true),
      topArtists: top(artistCounts, false),
      months: months,
      year: DateTime.now().year,
    );
  }
}

class _WrappedStoriesPageState extends State<WrappedStoriesPage>
    with TickerProviderStateMixin {
  static const slideCount = 9;
  static const slideDuration = Duration(milliseconds: 8500);

  int _slide = 0;
  bool _paused = false;
  Timer? _timer;
  late AnimationController _progress;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: slideDuration);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _startSlide() {
    _timer?.cancel();
    _progress.reset();
    if (_paused) return;
    _progress.forward();
    _timer = Timer(slideDuration, () {
      if (!mounted) return;
      if (_slide < slideCount - 1) {
        setState(() => _slide++);
        _startSlide();
      } else {
        setState(() => _paused = true);
      }
    });
  }

  void _go(int index) {
    if (index < 0 || index >= slideCount) return;
    setState(() => _slide = index);
    _startSlide();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _startSlide();
  }

  @override
  Widget build(BuildContext context) {
    final songs = Hive.box('SONG_HISTORY').values.whereType<Map>().toList();
    if (songs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Echo Wrapped'),
        ),
        body: const Center(
          child: Text('Ascolta qualche brano per creare il tuo Wrapped'),
        ),
      );
    }
    final data = WrappedData.fromHistory(songs);
    final theme = wrappedThemes[_slide.clamp(0, 8)];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        color: theme.background,
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _slideView(data, theme),
              ),
              // Top progress segments.
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(slideCount, (i) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (context, _) {
                              final value = i < _slide
                                  ? 1.0
                                  : i == _slide
                                      ? _progress.value
                                      : 0.0;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor:
                                      theme.headline.withValues(alpha: 0.25),
                                  color: theme.label,
                                ),
                              );
                            },
                          ),
                        ),
                      )),
                ),
              ),
              Positioned(
                top: 28,
                left: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: theme.headline),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 28,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    _paused ? Icons.play_arrow : Icons.pause,
                    color: theme.headline,
                  ),
                  onPressed: _togglePause,
                ),
              ),
              // Tap zones: left = previous, right = next.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.3,
                child: GestureDetector(
                  onTap: () => _go(_slide - 1),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.3,
                child: GestureDetector(
                  onTap: () => _go(_slide + 1),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slideView(WrappedData data, WrappedTheme t) => switch (_slide) {
        0 => _intro(data, t),
        1 => _minutes(data, t),
        2 => _exploration(data, t),
        3 => _topSong(data, t),
        4 => _topList(data.topSongs, 'TOP 5 CANZONI', t, Icons.music_note),
        5 => _topArtist(data, t),
        6 => _topList(data.topArtists, 'TOP 5 ARTISTI', t, Icons.person),
        7 => _persona(data, t),
        _ => _recap(data, t),
      };

  Widget _eyebrow(String text, Color color) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      );

  Widget _big(String text, Color color) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 64,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      );

  Widget _intro(WrappedData d, WrappedTheme t) => Center(
        key: const ValueKey(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyebrow('IL TUO ${d.year} IN MUSICA', t.label),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [t.headline, t.label, t.headline],
              ).createShader(b),
              child: const Text(
                'WRAPPED',
                style: TextStyle(
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              children: [
                _pill('${d.totalMinutes} MIN', t),
                _pill('${d.uniqueSongs} CANZONI', t),
                _pill('${d.uniqueArtists} ARTISTI', t),
              ],
            ),
            const SizedBox(height: 40),
            _eyebrow('TOCCA PER CONTINUARE', t.body),
          ],
        ),
      );

  Widget _pill(String text, WrappedTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.headline.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: TextStyle(
                color: t.headline, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _minutes(WrappedData d, WrappedTheme t) => Center(
        key: const ValueKey(1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyebrow('HAI ASCOLTATO', t.label),
            const SizedBox(height: 8),
            _big('${d.totalMinutes}', t.headline),
            Text('MINUTI', style: TextStyle(color: t.headline, fontSize: 24)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Sono ${(d.totalMinutes / 60).toStringAsFixed(1)} ore di musica '
                'che hanno accompagnato la tua giornata.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.body, fontSize: 16),
              ),
            ),
            const SizedBox(height: 28),
            const _EqBars(),
          ],
        ),
      );

  Widget _exploration(WrappedData d, WrappedTheme t) => Center(
        key: const ValueKey(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyebrow('LA TUA ESPLORAZIONE', t.label),
            const SizedBox(height: 24),
            _big('${d.uniqueSongs}', t.headline),
            Text('CANZONI DIVERSE',
                style: TextStyle(color: t.body, fontSize: 16)),
            const SizedBox(height: 24),
            _big('${d.uniqueArtists}', t.headline),
            Text('ARTISTI SCOPERTI',
                style: TextStyle(color: t.body, fontSize: 16)),
            const SizedBox(height: 32),
            if (d.totalMinutes > 3000) _pill('TOP 5%', t),
          ],
        ),
      );

  Widget _topSong(WrappedData d, WrappedTheme t) {
    final song = d.topSong;
    return Center(
      key: const ValueKey(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _eyebrow('LA TUA CANZONE PIÙ ASCOLTATA', t.label),
          const SizedBox(height: 24),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(Icons.album, size: 90, color: t.headline),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(song?.title ?? 'Nessuna canzone',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.headline,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ),
          Text(song?.artist ?? '',
              style: TextStyle(color: t.body, fontSize: 16)),
          const SizedBox(height: 12),
          _pill('${song?.count ?? 0} VOLTE', t),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: song == null
                ? null
                : () => GetIt.I<MediaPlayer>().playSong({
                      'videoId': song.videoId,
                      'title': song.title,
                      'artists': [
                        {'name': song.artist}
                      ],
                    }),
            style: FilledButton.styleFrom(backgroundColor: t.label),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Riascolta'),
          ),
        ],
      ),
    );
  }

  Widget _topList(List<PlayStat> items, String title, WrappedTheme t, IconData icon) =>
      Center(
        key: ValueKey(title),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyebrow(title, t.label),
            const SizedBox(height: 20),
            ...items.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                color: t.label,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ),
                      Icon(icon, color: t.headline, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.headline, fontSize: 16)),
                      ),
                      Text('${e.value.count}',
                          style: TextStyle(color: t.body, fontSize: 14)),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _topArtist(WrappedData d, WrappedTheme t) {
    final artist = d.topArtist;
    return Center(
      key: const ValueKey(5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _eyebrow('IL TUO ARTISTA NUMERO UNO', t.label),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: 1 + _pulse.value * 0.04,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.card,
                  boxShadow: [
                    BoxShadow(
                      color: t.label.withValues(alpha: 0.35 * _pulse.value),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.person, size: 90, color: t.headline),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(artist?.title ?? 'Nessuno',
              style: TextStyle(
                  color: t.headline, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _pill('${artist?.count ?? 0} ASCOLTI', t),
        ],
      ),
    );
  }

  Widget _persona(WrappedData d, WrappedTheme t) => Center(
        key: const ValueKey(7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyebrow('LA TUA PERSONALITÀ MUSICALE', t.label),
            const SizedBox(height: 16),
            Text(d.persona.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.headline,
                    fontSize: 36,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            _RadarMeter(
              values: [
                (d.uniqueArtists / 150).clamp(0.1, 1.0).toDouble(),
                (d.totalMinutes / 5000).clamp(0.1, 1.0).toDouble(),
                (d.uniqueSongs / 300).clamp(0.1, 1.0).toDouble(),
                (d.topSongs.isEmpty ? 0.2 : 0.9),
                0.7,
              ],
              color: t.label,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                _pill('ESPLORATORE', t),
                _pill('CURioso', t),
                _pill('MUSIC FAN', t),
              ],
            ),
          ],
        ),
      );

  Widget _recap(WrappedData d, WrappedTheme t) => Center(
        key: const ValueKey(8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.headline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _eyebrow('IL TUO ${d.year} IN MUSICA', t.label),
                const SizedBox(height: 8),
                Text('WRAPPED',
                    style: TextStyle(
                        color: t.headline,
                        fontSize: 40,
                        fontWeight: FontWeight.w900)),
                const Divider(height: 32),
                _recapRow(Icons.music_note, 'Canzone top',
                    d.topSong?.title ?? '—', t),
                _recapRow(Icons.person, 'Artista top',
                    d.topArtist?.title ?? '—', t),
                _recapRow(Icons.access_time, 'Minuti totali',
                    '${d.totalMinutes}', t),
                _recapRow(Icons.disc_full, 'Canzoni',
                    '${d.uniqueSongs}', t),
                const SizedBox(height: 20),
                _eyebrow('TOP 5 BRANI', t.label),
                ...d.topSongs.map((s) => Text(s.title,
                    style: TextStyle(color: t.body, fontSize: 14))),
                const SizedBox(height: 16),
                _eyebrow('TOP 5 ARTISTI', t.label),
                ...d.topArtists.map((s) => Text(s.title,
                    style: TextStyle(color: t.body, fontSize: 14))),
              ],
            ),
          ),
        ),
      );

  Widget _recapRow(IconData icon, String label, String value, WrappedTheme t) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: t.label, size: 20),
            const SizedBox(width: 10),
            Text('$label: ',
                style: TextStyle(color: t.body, fontSize: 14)),
            Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.headline,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

class _EqBars extends StatefulWidget {
  const _EqBars();

  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 70,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(18, (i) {
              final h = 12 +
                  48 *
                      (0.5 +
                          0.5 *
                              math.sin(
                                _controller.value * math.pi * 4 + i * 0.7));
              return Container(
                width: 6,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      );
}

class _RadarMeter extends StatelessWidget {
  const _RadarMeter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(
          painter: _RadarPainter(values: values, color: color),
          size: const Size(220, 220),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final count = values.length;
    final point = (int i, double r) {
      final angle = i * 2 * math.pi / count - math.pi / 2;
      return center + Offset(math.cos(angle), math.sin(angle)) * r;
    };
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = point(i, radius * ring / 4);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke);
    }
    final dataPath = Path();
    for (var i = 0; i < count; i++) {
      final p = point(i, radius * values[i].clamp(0.0, 1.0));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(
        dataPath,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        dataPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values;
}
