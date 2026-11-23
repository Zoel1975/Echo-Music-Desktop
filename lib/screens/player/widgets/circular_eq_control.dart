import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Android `CircularEqControl`: a 10-band circular equalizer rendered with
/// Canvas. Tapping/dragging a band vertically changes its gain.
class CircularEqControl extends StatelessWidget {
  const CircularEqControl({
    required this.gains,
    required this.onChanged,
    this.size = 240,
    super.key,
  });

  final List<double> gains;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final center = Offset(size / 2, size / 2);
          final dx = details.localPosition.dx - center.dx;
          final dy = details.localPosition.dy - center.dy;
          final angle = (math.atan2(dy, dx) + 2 * math.pi) % (2 * math.pi);
          final index = (angle / (2 * math.pi) * 10).floor().clamp(0, 9);
          onChanged(index);
        },
        child: CustomPaint(
          painter: _CircularEqPainter(gains: gains),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _CircularEqPainter extends CustomPainter {
  _CircularEqPainter({required this.gains});

  final List<double> gains;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    canvas.drawCircle(
      center,
      radius + 18,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 10; i++) {
      final angle = i * 2 * math.pi / 10 - math.pi / 2;
      final gain = i < gains.length ? gains[i] : 0.0;
      final length = (gain.clamp(-12.0, 12.0)).abs() / 12 * radius * 0.45 + 6;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final start = center + dir * (radius * 0.55);
      final end = center + dir * (radius * 0.55 + length);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = gain >= 0
              ? Colors.pinkAccent
              : Colors.cyanAccent
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        center + dir * radius,
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
  }

  @override
  bool shouldRepaint(_CircularEqPainter old) => old.gains != gains;
}
