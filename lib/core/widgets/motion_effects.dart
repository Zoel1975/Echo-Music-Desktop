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
