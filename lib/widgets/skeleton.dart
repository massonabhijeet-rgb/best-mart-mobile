import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'product_card.dart';
import 'section_background.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final t = _ctrl.value;
          return LinearGradient(
            begin: Alignment(-1 + 2 * t, 0),
            end: Alignment(1 + 2 * t, 0),
            colors: const [
              Color(0xFFE9EEF7),
              Color(0xFFF5F8FE),
              Color(0xFFE9EEF7),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppRadius.brSm,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEF7),
          borderRadius: borderRadius,
        ),
      );
}

class ProductCardSkeleton extends StatelessWidget {
  final double width;
  const ProductCardSkeleton({super.key, this.width = 110});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: ProductCard.totalHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBox(
              height: ProductCard.imageHeight,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 10, width: double.infinity),
                  SizedBox(height: 6),
                  SkeletonBox(height: 10, width: 70),
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: 50),
                  SizedBox(height: 12),
                  SkeletonBox(height: 28, width: double.infinity),
                ],
              ),
            ),
          ],
        ),
      );
}

class HomeRailSkeleton extends StatelessWidget {
  final SectionTint tint;
  const HomeRailSkeleton({super.key, this.tint = SectionTint.sky});

  @override
  Widget build(BuildContext context) => SectionBackground(
        tint: tint,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          0,
          AppSpacing.lg,
        ),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  children: const [
                    SkeletonBox(height: 32, width: 32),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(height: 14, width: 160),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: ProductCard.totalHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  itemCount: 4,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, __) => const ProductCardSkeleton(),
                ),
              ),
            ],
          ),
        ),
      );
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: AppSpacing.md),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Shimmer(child: SkeletonBox(height: 48)),
          ),
          SizedBox(height: AppSpacing.md),
          HomeRailSkeleton(tint: SectionTint.yellow),
          HomeRailSkeleton(tint: SectionTint.peach),
          HomeRailSkeleton(tint: SectionTint.mint),
        ],
      );
}
