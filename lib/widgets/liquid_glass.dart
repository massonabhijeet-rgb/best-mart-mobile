import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Static, professional storefront backdrop: a soft top-to-bottom
/// gradient (light brand-blue tint fading to white). Replaces the
/// earlier drifting "liquid blob" animation, which read as the
/// background color shifting around. Foreground content (search bar,
/// app bar, cards) layers on top with `BackdropFilter` and translucent
/// surfaces — the glass cue still works because the surfaces are
/// translucent over a coloured field, no animation required.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;
  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft, fixed top-to-bottom gradient.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD9E6F7), // light brand-blue at top
                Color(0xFFE7EFFA), // mid
                Color(0xFFFFFFFF), // white deep down
              ],
              stops: [0.0, 0.30, 0.65],
            ),
          ),
          child: SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}

/// Translucent + blurred surface used for app bars, search bars,
/// sheets, popups, etc. Reads as "glass" because it picks up the
/// background colours behind it through a Gaussian blur.
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
