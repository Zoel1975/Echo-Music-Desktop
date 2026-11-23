import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/services/settings_manager.dart';

import 'animated_gradient_bg.dart';

/// The seven player backgrounds from Android's `Player.kt`. Kept as strings
/// for Hive compatibility with older installs.
class PlayerBackgroundStyle {
  static const defaultStyle = 'Default';
  static const gradient = 'Gradient';
  static const blur = 'Blur';
  static const glowAnimated = 'Glow animated';
  static const appleMusic = 'Apple Music';
  static const liveMesh = 'Live mesh';
  static const liquidGlass = 'Liquid glass';

  static const all = [
    defaultStyle,
    gradient,
    blur,
    glowAnimated,
    appleMusic,
    liveMesh,
    liquidGlass,
  ];

  /// Old installs used 'Solid'/'Artwork'; map them to the closest new style.
  static String normalize(String value) {
    if (all.contains(value)) return value;
    if (value == 'Solid') return defaultStyle;
    if (value == 'Artwork') return blur;
    return gradient;
  }
}

/// Renders the selected Android-style player background behind [child].
class PlayerBackground extends StatelessWidget {
  const PlayerBackground({
    required this.style,
    required this.colors,
    required this.child,
    this.artwork,
    super.key,
  });

  final String style;
  final List<Color> colors;
  final Widget? artwork;
  final Widget child;

  List<Color> get _palette => colors.isEmpty
      ? [
          Colors.deepPurple.shade900,
          Colors.purple.shade800,
          Colors.indigo.shade900,
          Colors.black,
        ]
      : colors;

  @override
  Widget build(BuildContext context) {
    final resolved = PlayerBackgroundStyle.normalize(style);
    return switch (resolved) {
      PlayerBackgroundStyle.defaultStyle => _solid(context),
      PlayerBackgroundStyle.gradient => _gradient(context, 8),
      PlayerBackgroundStyle.blur => _artworkBlur(context, 24, 0.45),
      PlayerBackgroundStyle.glowAnimated => _gradient(context, 20),
      PlayerBackgroundStyle.appleMusic => _artworkBlur(context, 24, 0.62),
      PlayerBackgroundStyle.liveMesh => _mesh(context),
      PlayerBackgroundStyle.liquidGlass => _liquidGlass(context),
      _ => _solid(context),
    };
  }

  Widget _solid(BuildContext context) => ColoredBox(
        color: Color.alphaBlend(
          _palette.first.withValues(alpha: 0.18),
          const Color(0xFF090909),
        ),
        child: child,
      );

  Widget _gradient(BuildContext context, int seconds) => Stack(
        children: [
          Positioned.fill(
            child: AnimatedGradientBackground(
              colors: _palette,
              animationDuration: Duration(seconds: seconds),
            ),
          ),
          child,
        ],
      );

  Widget _artworkBlur(BuildContext context, double sigma, double scrim) =>
      Stack(
        children: [
          if (artwork != null)
            Positioned.fill(
              child: ImageFilterView(sigma: sigma, child: artwork!),
            )
          else
            Positioned.fill(child: _gradientOnly()),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: scrim)),
          ),
          child,
        ],
      );

  Widget _gradientOnly() => AnimatedGradientBackground(
        colors: _palette,
        animationDuration: const Duration(seconds: 20),
      );

  Widget _mesh(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: _MeshBackground(colors: _palette)),
          child,
        ],
      );

  Widget _liquidGlass(BuildContext context) {
    // Android's "Glass player" toggle: without glass the artwork stays sharp
    // and the translucent tint is skipped.
    final glass = GetIt.I<SettingsManager>().extra<bool>('glassPlayer', true);
    return Stack(
        children: [
          // Base is the artwork, softly blurred as in Android's glass player.
          Positioned.fill(
            child: artwork != null
                ? glass
                    ? ImageFilterView(sigma: 24, child: artwork!)
                    : artwork!
                : _gradientOnly(),
          ),
          // A single translucent tint. Adding a second BackdropFilter here
          // used to double-blur and produce dark/striped artifacts.
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                  width: 1,
                ),
              ),
            ),
          ),
          child,
        ],
      );
  }

  static ImageFilter uiBlur(double sigma) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
}

/// Blurs the artwork ITSELF. BackdropFilter blurs what is behind the widget
/// (which made the old implementation blur the gradient and leave the cover
/// sharp); ImageFiltered applies the filter to the child.
class ImageFilterView extends StatelessWidget {
  const ImageFilterView({required this.sigma, required this.child, super.key});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Large sigma values on a full-screen layer produced dark fringes and
    // stale frames with Impeller. Cap the blur and scale the overscan with it.
    final safeSigma = sigma.clamp(0.0, 24.0);
    return LayoutBuilder(
      builder: (context, box) {
        final overscan = 1 +
            (3 * safeSigma) /
                math.max(1.0, math.min(box.maxWidth, box.maxHeight));
        return RepaintBoundary(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: safeSigma,
                sigmaY: safeSigma,
              ),
              child: Transform.scale(scale: overscan, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Animated live-mesh background (6 orbiting radial spots).
class _MeshBackground extends StatefulWidget {
  const _MeshBackground({required this.colors});

  final List<Color> colors;

  @override
  State<_MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<_MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _MeshPainter(
            colors: widget.colors,
            animation: _controller.value,
          ),
          size: Size.infinite,
        ),
      );
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({required this.colors, required this.animation});

  final List<Color> colors;
  final double animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0B0B12));
    final t = animation;
    for (var i = 0; i < 6; i++) {
      final color = colors[i % colors.length];
      final cx = size.width *
          (0.5 + 0.42 * math.sin(t * 2 * math.pi + i * 1.05));
      final cy = size.height *
          (0.5 + 0.38 * math.cos(t * 2 * math.pi + i * 0.83));
      final radius = size.width * (0.45 + 0.08 * math.sin(t * 6 + i));
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
          ..blendMode = BlendMode.screen,
      );
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) => true;
}
