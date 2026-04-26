import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// iOS-26-style "liquid glass" backdrop for a screen.
///
/// Renders three slowly-drifting blurred color blobs in the deepest
/// layer, plus a soft top-down gradient over them. Foreground content
/// (search bar, app bar, cards) layers on top with `BackdropFilter` to
/// pick up the blob colors as a real refractive blur — that's the
/// thing that gives the "glass" look depth instead of looking like a
/// flat tint.
///
/// Use as the body of a Scaffold:
///
///     Scaffold(
///       body: LiquidGlassBackground(child: yourContent),
///     )
class LiquidGlassBackground extends StatefulWidget {
  final Widget child;
  const LiquidGlassBackground({super.key, required this.child});

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with TickerProviderStateMixin {
  // Long-period animation — blobs drift slowly so they read as ambient
  // depth, not as motion.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base color so the blobs sit on a clean canvas even on slow
        // GPUs that struggle with the blur shader.
        const ColoredBox(color: AppColors.pageBg),

        // Animated blobs — three colored ellipses drifting on lissajous
        // paths. Heavy blur turns them into soft backdrops; the
        // RepaintBoundary keeps the blob layer from invalidating the
        // whole tree on every animation tick.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _BlobPainter(_ctrl.value),
            ),
          ),
        ),

        // Subtle top-to-bottom fade so the hero band stays readable
        // (text + chips sit over the lighter top area).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66FFFFFF), // 40% white at top
                Color(0x00FFFFFF), // transparent mid
                Color(0x80FFFFFF), // 50% white deeper down
              ],
              stops: [0, 0.4, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),

        // Foreground content.
        widget.child,
      ],
    );
  }
}

/// Drifting blobs renderer. Three colored blurred ellipses positioned
/// on slow lissajous curves so the composition keeps changing without
/// ever looking "spinning" or repetitive.
class _BlobPainter extends CustomPainter {
  final double t; // 0..1 over the controller's full period
  _BlobPainter(this.t);

  static const _blobs = <_BlobSpec>[
    _BlobSpec(
      color: Color(0xFF8AB4F8), // soft brand blue
      radius: 0.55,
      ax: 0.28, ay: 0.32, // amplitude as % of size
      cx: 0.20, cy: 0.18, // base center
      px: 1.0, py: 1.4,   // x,y phase multipliers (different = lissajous)
    ),
    _BlobSpec(
      color: Color(0xFFFFC9A1), // warm coral
      radius: 0.50,
      ax: 0.30, ay: 0.28,
      cx: 0.85, cy: 0.30,
      px: 1.3, py: 0.9,
    ),
    _BlobSpec(
      color: Color(0xFFB7E6CC), // mint
      radius: 0.60,
      ax: 0.34, ay: 0.30,
      cx: 0.55, cy: 0.85,
      px: 0.8, py: 1.1,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Heavy blur via MaskFilter — makes the colored circles look like
    // soft ambient lighting instead of crisp shapes.
    final blur = MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.18);

    for (final b in _blobs) {
      final rad = b.radius * size.shortestSide;
      final cx = (b.cx + b.ax * math.sin(t * 2 * math.pi * b.px)) * size.width;
      final cy =
          (b.cy + b.ay * math.cos(t * 2 * math.pi * b.py)) * size.height;
      final paint = Paint()
        ..color = b.color
        ..maskFilter = blur;
      canvas.drawCircle(Offset(cx, cy), rad, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) => old.t != t;
}

class _BlobSpec {
  final Color color;
  final double radius;
  final double ax, ay;
  final double cx, cy;
  final double px, py;
  const _BlobSpec({
    required this.color,
    required this.radius,
    required this.ax,
    required this.ay,
    required this.cx,
    required this.cy,
    required this.px,
    required this.py,
  });
}

/// Translucent + blurred surface used for app bars, search bars,
/// sheets, popups, etc. Reads as "glass" because it picks up the
/// blob colors behind it through a Gaussian blur.
///
/// `tint` controls how white/dark the glass is — tweak per surface.
/// Pass `borderRadius` to get the rounded clipping; default is 0.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double sigma;
  final Color tint;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  const GlassPanel({
    super.key,
    required this.child,
    this.sigma = 22,
    this.tint = const Color(0x99FFFFFF), // 60% white
    this.borderRadius = BorderRadius.zero,
    this.padding = EdgeInsets.zero,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
