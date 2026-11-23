import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/models/lyrics_model.dart'; // Import the new model
import 'package:Echo/services/lyrics.dart'; // Import the new service
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/settings_manager.dart';
import 'translation_dialog.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LyricsBox extends StatefulWidget {
  const LyricsBox({
    required this.currentSong,
    required this.size,
    this.onLyricsFound,
    super.key,
  });
  final MediaItem currentSong;
  final Size size;
  final Function(bool)? onLyricsFound;

  @override
  State<LyricsBox> createState() => _LyricsBoxState();
}

class _LyricsBoxState extends State<LyricsBox> {
  Future<Lyrics>? _fetchLyricsFuture;
  /// Invalidates results from a previous track: a slow provider could otherwise
  /// overwrite the current song's lyrics after a quick track change.
  int _fetchGeneration = 0;
  bool _lyricsLoaded = false;
  List<String>? _translatedLines;
  Lyrics? _lyrics;

  @override
  void initState() {
    super.initState();
    _initFetchLyrics();
    _initWakelock();
  }

  void _initFetchLyrics() {
    _fetchLyrics();
  }

  void _initWakelock() {
    GetIt.I<MediaPlayer>().buttonState.addListener(_updateWakelock);
  }

  void _updateWakelock() {
    if (!mounted) return;
    final isPlaying =
        GetIt.I<MediaPlayer>().buttonState.value == ButtonState.playing;
    if (isPlaying && _lyricsLoaded) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void didUpdateWidget(covariant LyricsBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSong.id != oldWidget.currentSong.id) {
      _initFetchLyrics();
    }
  }

  void _fetchLyrics() {
    if (!mounted) return;
    final generation = ++_fetchGeneration;
    setState(() {
      _translatedLines = null;
      _lyrics = null;
      _lyricsLoaded = false;
      _fetchLyricsFuture = GetIt.I<LyricsService>().getLyrics(
        title: widget.currentSong.title,
        artist: widget.currentSong.artist,
        album: widget.currentSong.album,
        duration: widget.currentSong.duration?.inSeconds.toString(),
      );
    });
    _fetchLyricsFuture!.then((lyrics) {
      if (!mounted || generation != _fetchGeneration) return;
      _lyrics = lyrics;
      _lyricsLoaded = (lyrics.parsedLyrics?.lyrics.isNotEmpty ?? false) ||
          lyrics.lyricsPlain.isNotEmpty;
      _maybeAutoRomanize(lyrics, generation);
      widget.onLyricsFound?.call(_lyricsLoaded);
      _updateWakelock();
    }).catchError((_) {
      if (!mounted || generation != _fetchGeneration) return;
      _lyricsLoaded = false;
      widget.onLyricsFound?.call(false);
      _updateWakelock();
    });
  }

  @override
  void dispose() {
    GetIt.I<MediaPlayer>().buttonState.removeListener(_updateWakelock);
    WakelockPlus.disable();
    super.dispose();
  }

  /// Android's "Lyrics romanization": transliterate automatically after a
  /// fetch when enabled. "Show romanized as main" is applied by the lyric
  /// widgets when deciding which text to render first.
  Future<void> _maybeAutoRomanize(Lyrics lyrics, int generation) async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.lyricsRomanization || !settings.translateLyrics) return;
    final lines = lyrics.lyricsPlain
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    try {
      final translated = await GetIt.I<LyricsService>().translateLyrics(
        lines: lines,
        targetLanguage: settings.translationLanguage,
        mode: 'Romanized',
        provider: settings.translationProvider,
        apiKey: settings.translationApiKey,
        baseUrl: settings.translationBaseUrl,
        model: settings.translationModel,
        deeplApiKey: settings.extra<String>('deeplApiKey', ''),
        useStreaming: settings.translationStreaming,
      );
      if (mounted && generation == _fetchGeneration) {
        setState(() => _translatedLines = translated);
      }
    } catch (_) {}
  }

  void _showTranslationDialog(Lyrics lyrics) {
    final lines = <String>[
      if (lyrics.lyricsPlain.isNotEmpty) ...lyrics.lyricsPlain.split('\n'),
      ...?lyrics.parsedLyrics?.lyrics.map((l) => l.text),
    ].where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => TranslationDialog(
        lines: lines,
        service: GetIt.I<LyricsService>(),
        settings: GetIt.I<SettingsManager>(),
        onResult: (translated) {
          if (!mounted) return;
          setState(() => _translatedLines = translated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Center(
            child: _fetchLyricsFuture != null
                ? FutureBuilder<Lyrics>(
                    future: _fetchLyricsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        if (snapshot.data == null) {
                          return const Text('No Lyrics Found (Null)');
                        }
                        return LoadedLyricsWidget(
                          lyrics: snapshot.data!,
                          translatedLines: _translatedLines,
                        );
                      }
                      if (snapshot.hasError) {
                        return const Text('No Lyrics Found');
                      }
                      return const ExpressiveLoadingIndicator();
                    },
                  )
                : const ExpressiveLoadingIndicator(),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                tooltip: 'Translate lyrics',
                onPressed: () {
                  if (!GetIt.I<SettingsManager>().translateLyrics) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Abilita "Traduci testi" nelle impostazioni YT Music',
                        ),
                      ),
                    );
                    return;
                  }
                  final lyrics = _lyrics;
                  if (lyrics != null) _showTranslationDialog(lyrics);
                },
                icon: const Icon(Icons.translate, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadedLyricsWidget extends StatelessWidget {
  final Lyrics lyrics;
  final List<String>? translatedLines;
  const LoadedLyricsWidget({
    super.key,
    required this.lyrics,
    this.translatedLines,
  });

  @override
  Widget build(BuildContext context) {
    if ((lyrics.parsedLyrics?.lyrics.isEmpty ?? true) &&
        lyrics.lyricsPlain.isNotEmpty) {
      return PlainLyricsWidget(
          lyrics: lyrics, translatedLines: translatedLines);
    } else if (lyrics.parsedLyrics?.lyrics.isNotEmpty ?? false) {
      return SyncedLyricsWidget(
        lyrics: lyrics,
        translatedLines: translatedLines,
      );
    }
    return const Center(
      child: Text("No Lyrics found!"),
    );
  }
}

class PlainLyricsWidget extends StatelessWidget {
  final Lyrics lyrics;
  final List<String>? translatedLines;
  const PlainLyricsWidget({
    super.key,
    required this.lyrics,
    this.translatedLines,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: SelectableText(
          () {
            final settings = GetIt.I<SettingsManager>();
            final hasTranslated = translatedLines != null &&
                translatedLines!.isNotEmpty;
            final swap = hasTranslated && settings.romanizeAsMain;
            final primary =
                swap ? translatedLines!.join('\n') : lyrics.lyricsPlain;
            final secondary = swap
                ? lyrics.lyricsPlain
                : (hasTranslated ? translatedLines!.join('\n') : '');
            return '\n$primary\n${secondary.isEmpty ? '' : '\n$secondary'}';
          }(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: GetIt.I<SettingsManager>().lyricsTextSize + 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.4 + GetIt.I<SettingsManager>().extra<double>('lyricsLineSpacing', 8) / 40,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final Lyrics lyrics;
  final List<String>? translatedLines;
  const SyncedLyricsWidget({
    required this.lyrics,
    this.translatedLines,
    super.key,
  });

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget>
    with TickerProviderStateMixin {
  StreamSubscription? _streamSubscription;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Duration duration = Duration.zero;
  int _currentLyricIndex = 0;
  
  // Scrolling Logic
  bool _isUserScrolling = false;
  Timer? _userScrollTimer;
  final Duration _userScrollCooldown = const Duration(milliseconds: 1500);

  // Animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Glow animation for current lyric
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Slower breathing
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Verify MediaPlayer availability
    try {
      _streamSubscription =
          GetIt.I<MediaPlayer>().player.positionStream.listen((event) {
        if (mounted) {
          duration = event;
          final newIndex = _findCurrentLyricIndex();
          // Only update if the lyric index actually changed
          if (newIndex != _currentLyricIndex) {
            setState(() {
              _currentLyricIndex = newIndex;
            });
            _scrollToCurrentLyric(newIndex);
          }
        }
      });
    } catch (e) {
      print("Error attaching position stream: $e");
    }
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _glowController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _scrollToCurrentLyric(int index) {
    // Android's "Auto scroll lyrics" preference.
    if (!GetIt.I<SettingsManager>().lyricsAutoScroll) return;
    if (_itemScrollController.isAttached && !_isUserScrolling) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 700), // Smoother scroll
        curve: Curves.easeOutCubic, // Apple Music-like curve
        alignment: 0.5, // Center alignment
      );
    }
  }

  int _findCurrentLyricIndex() {
    if (widget.lyrics.parsedLyrics == null) return 0;

    final lines = widget.lyrics.parsedLyrics!.lyrics;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].start.inMilliseconds > duration.inMilliseconds) {
        return i > 0 ? i - 1 : 0;
      }
    }
    return lines.length - 1;
  }

  bool isCurrentLyric(int index) {
    return index == _currentLyricIndex;
  }

  // Seek to the tapped lyric's timestamp
  void _seekToLyric(int index) {
    if (widget.lyrics.parsedLyrics == null) return;
    final lyric = widget.lyrics.parsedLyrics!.lyrics[index];
    GetIt.I<MediaPlayer>().player.seek(lyric.start);
    // Explicitly scroll to tapped lyric
    _scrollToCurrentLyric(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.parsedLyrics == null) return const SizedBox();

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, 0.15, 0.85, 1.0], // Increased fade area
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
           if (notification.direction != ScrollDirection.idle) {
            // User is scrolling
            setState(() {
              _isUserScrolling = true;
            });
            _userScrollTimer?.cancel();
          } else {
             // Scroll ended (idle) - start cooldown
             _userScrollTimer?.cancel();
             _userScrollTimer = Timer(_userScrollCooldown, () {
               if (mounted) {
                 setState(() {
                   _isUserScrolling = false;
                 });
                 // Resume follow mode
                 _scrollToCurrentLyric(_currentLyricIndex);
               }
             });
          }
          return false;
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            itemCount: widget.lyrics.parsedLyrics!.lyrics.length,
            // Huge padding to allow first and last items to be centered
            padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.height / 2.5),
            itemBuilder: (context, index) {
              final isCurrent = isCurrentLyric(index);
              final lyricText = widget.lyrics.parsedLyrics!.lyrics[index].text;
              
              // Only apply blur if not current and not too close to current (optional optimization)
              // For now, simpler is better: Opacity handle focus
              
              // Geometry must NOT change when the active line changes:
              // animating fontSize/weight/letterSpacing made every item
              // re-measure and the list re-paginate ("justified" look).
              final settings = GetIt.I<SettingsManager>();
              const baseSize = 32.0;
              final fontSize = baseSize + (settings.lyricsTextSize - 18) / 2;
              final height = 1.3 + settings.extra<double>('lyricsLineSpacing', 8) / 40;
              TextStyle style(double glow) => TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: height,
                    letterSpacing: 0.0,
                    color: isCurrent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    shadows: isCurrent
                        ? [
                            Shadow(
                              color: Colors.white.withValues(alpha: glow * 0.8),
                              blurRadius: 15,
                            ),
                            Shadow(
                              color: Colors.white.withValues(alpha: glow * 0.4),
                              blurRadius: 30,
                            ),
                            Shadow(
                              color: Colors.blueAccent.withValues(alpha: glow * 0.3),
                              blurRadius: 50,
                            ),
                          ]
                        : const [],
                  );
              Widget lyricLine(double glow) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lyricText, textAlign: TextAlign.center, style: style(glow)),
                      if (widget.translatedLines != null &&
                          index < widget.translatedLines!.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.translatedLines![index],
                            textAlign: switch (GetIt.I<SettingsManager>().lyricsTextPosition) {
             'Left' => TextAlign.left,
             'Right' => TextAlign.right,
             _ => TextAlign.center,
           },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white
                                  .withValues(alpha: isCurrent ? 0.85 : 0.4),
                            ),
                          ),
                        ),
                    ],
                  );

              return GestureDetector(
                onTap: () => _seekToLyric(index),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32),
                  // Only the active line rebuilds on the glow tick.
                  child: isCurrent
                      ? AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, _) => lyricLine(_glowAnimation.value),
                        )
                      : lyricLine(0),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// AnimatedBuilder is a simpler version of AnimatedWidget for inline use
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}