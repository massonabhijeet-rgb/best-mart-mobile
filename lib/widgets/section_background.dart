import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum SectionTint { yellow, peach, mint, sky, lavender, none }

class SectionBackground extends StatelessWidget {
  final SectionTint tint;
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const SectionBackground({
    super.key,
    required this.child,
    this.tint = SectionTint.sky,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.lg,
    ),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  Color get _bg {
    switch (tint) {
      case SectionTint.yellow:
        return AppColors.sectionYellow;
      case SectionTint.peach:
        return AppColors.sectionPeach;
      case SectionTint.mint:
        return AppColors.sectionMint;
      case SectionTint.sky:
        return AppColors.sectionSky;
      case SectionTint.lavender:
        return AppColors.sectionLavender;
      case SectionTint.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: AppRadius.brLg,
        ),
        child: child,
      );
}
