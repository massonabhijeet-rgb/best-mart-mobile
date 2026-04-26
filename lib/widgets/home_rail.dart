import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'product_card.dart';
import 'section_background.dart';

class HomeRail extends StatefulWidget {
  final String title;
  final String emoji;
  final String? subtitle;
  final List<Product> products;
  final SectionTint tint;
  final VoidCallback? onSeeAll;
  final VoidCallback? onLoadMore;
  final bool loadingMore;
  final bool hasMore;

  const HomeRail({
    super.key,
    required this.title,
    required this.emoji,
    required this.products,
    this.subtitle,
    this.tint = SectionTint.sky,
    this.onSeeAll,
    this.onLoadMore,
    this.loadingMore = false,
    this.hasMore = false,
  });

  @override
  State<HomeRail> createState() => _HomeRailState();
}

class _HomeRailState extends State<HomeRail> {
  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.hasMore || widget.loadingMore || widget.onLoadMore == null) return;
    if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 220) {
      widget.onLoadMore!();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionBackground(
      tint: widget.tint,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        0,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(
              children: [
                _EmojiBadge(emoji: widget.emoji),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // One-time shine sweep across the section title on
                      // first paint — a brighter band slides left → right
                      // over the dark text. TweenAnimationBuilder fires
                      // once per HomeRail mount so it doesn't loop and
                      // become distracting.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          return ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(-1.5 + 3 * t, 0),
                                end: Alignment(-0.5 + 3 * t, 0),
                                colors: const [
                                  AppColors.ink,
                                  Colors.white,
                                  AppColors.ink,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            child: child,
                          );
                        },
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkFaint,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onSeeAll != null)
                  TextButton(
                    onPressed: widget.onSeeAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right,
                            size: 16, color: AppColors.brandBlue),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: ProductCard.totalHeight,
            child: ListView.separated(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppSpacing.md),
              itemCount: widget.products.length + (widget.loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) {
                if (i >= widget.products.length) {
                  return const SizedBox(
                    width: 80,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ),
                  );
                }
                return ProductCard(product: widget.products[i]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  final String emoji;
  const _EmojiBadge({required this.emoji});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppShadow.soft,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      );
}
