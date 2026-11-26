import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

/// Android `WavySlider` / `SquigglySlider` equivalents. Both are CustomPainter
/// based: one animated sine path, one evenly spaced squiggle path.
class WavySlider extends StatefulWidget {
  const WavySlider({
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x33FFFFFF),
    this.squiggly = false,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final Color inactiveColor;
  final bool squiggly;

  @override
  State<WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<WavySlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 32.0;
        return SizedBox(
          height: height,
          width: width,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final v = (details.localPosition.dx / width).clamp(0.0, 1.0);
              widget.onChanged(v);
            },
            onTapDown: (details) {
              final v = (details.localPosition.dx / width).clamp(0.0, 1.0);
              widget.onChanged(v);
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _WavePainter(
                  value: widget.value.clamp(0.0, 1.0),
                  phase: _controller.value * 2 * math.pi,
                  active: widget.activeColor,
                  inactive: widget.inactiveColor,
                  squiggly: widget.squiggly,
                ),
                size: Size(width, height),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.phase,
    required this.active,
    required this.inactive,
    required this.squiggly,
  });

  final double value;
  final double phase;
  final Color active;
  final Color inactive;
  final bool squiggly;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final activeEnd = size.width * value;
    for (final segment in [
      (0.0, activeEnd, active),
      (activeEnd, size.width, inactive),
    ]) {
      final path = Path()..moveTo(segment.$1, mid);
      for (var x = segment.$1; x <= segment.$2; x += 2) {
        final t = (x - segment.$1) / math.max(1.0, segment.$2 - segment.$1);
        final y = mid +
            math.sin(t * math.pi * 8 + phase) * (squiggly ? 6.0 : 3.0);
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = segment.$3
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      Offset(activeEnd, mid),
      7,
      Paint()..color = active,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value || old.phase != phase || old.squiggly != squiggly;
}

/// Android `HeartBurstIcon`: six radial particles when the heart is liked.
class HeartBurst extends StatelessWidget {
  const HeartBurst({
    required this.liked,
    required this.onTap,
    this.color = Colors.redAccent,
    super.key,
  });

  final bool liked;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? color : Colors.white70,
                size: 24,
              ),
              if (liked)
                ...List.generate(6, (i) {
                  final angle = i * math.pi / 3;
                  return Transform.translate(
                    offset: Offset(
                      18 * math.cos(angle),
                      18 * math.sin(angle),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: color.withValues(alpha: 0.75),
                      size: 7,
                    ),
                  );
                }),
            ],
          ),
        ),
      );
}

/// Reusable shimmer placeholder (Android `component/shimmer/*`).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.04),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Container(
              width: width,
              height: height,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      );
}

/// Android's "Rotating thumbnail" preference: slow continuous rotation of the
/// playing artwork. Only created when enabled, so lists pay nothing.
class RotatingArt extends StatefulWidget {
  const RotatingArt({
    required this.child,
    required this.enabled,
    super.key,
  });

  final Widget child;
  final bool enabled;

  @override
  State<RotatingArt> createState() => _RotatingArtState();
}

class _RotatingArtState extends State<RotatingArt>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant RotatingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (widget.enabled && _spin == null) {
      _spin = AnimationController(
          vsync: this, duration: const Duration(seconds: 14))
        ..repeat();
    } else if (!widget.enabled && _spin != null) {
      _spin!.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spin = _spin;
    if (spin == null) return widget.child;
    // A rotating square clipped by the artwork's rounded rectangle produces a
    // broken polygon (its corners leave the container at 45 degrees). Clip to
    // a circle instead: a square rotated about its center always covers its
    // own inscribed circle, so the result is a clean spinning record.
    return ClipOval(
      child: RotationTransition(turns: spin, child: widget.child),
    );
  }
}

/// Android's "Swipe to change song" + "Swipe sensitivity" preferences for the
/// player artwork. A horizontal drag past [threshold] switches track.
class SongSwipeDetector extends StatelessWidget {
  const SongSwipeDetector({
    required this.child,
    required this.enabled,
    required this.threshold,
    required this.onNext,
    required this.onPrevious,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double threshold;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < threshold) return;
        if (velocity < 0) {
          onNext();
        } else {
          onPrevious();
        }
      },
      child: child,
    );
  }
}

/// "Wavy play/pause button": an animated icon that morphs between play and
/// pause instead of swapping a static glyph.
class WavyPlayPause extends StatefulWidget {
  const WavyPlayPause({required this.playing, super.key});

  final bool playing;

  @override
  State<WavyPlayPause> createState() => _WavyPlayPauseState();
}

class _WavyPlayPauseState extends State<WavyPlayPause>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didUpdateWidget(covariant WavyPlayPause oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      widget.playing ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _controller,
        size: 32,
        color: Colors.black,
      );
}

/// Marquee used in Android's player, mini-player, queue and search.
class MarqueeText extends StatelessWidget {
  const MarqueeText(
    this.text, {
    required this.style,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => TextScroll(
        text,
        style: style,
        mode: TextScrollMode.bouncing,
        velocity: const Velocity(pixelsPerSecond: Offset(24, 0)),
        delayBefore: const Duration(milliseconds: 1200),
        pauseBetween: const Duration(milliseconds: 800),
        textAlign: textAlign,
        selectable: false,
      );
}
