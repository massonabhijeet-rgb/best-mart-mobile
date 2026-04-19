import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'product_card.dart';

class CheckoutDeals extends StatelessWidget {
  final List<Product> pool;
  final Set<String> excludeIds;

  const CheckoutDeals({
    super.key,
    required this.pool,
    required this.excludeIds,
  });

  @override
  Widget build(BuildContext context) {
    final items = pool
        .where((p) => !excludeIds.contains(p.uniqueId) && p.stockQuantity > 0)
        .toList();
    items.sort((a, b) {
      final da = _discountPct(a);
      final db = _discountPct(b);
      return db.compareTo(da);
    });
    final visible = items.take(10).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadow.soft,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        0,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add more, save more',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.ink,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Top deals you can toss in before checkout',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkFaint,
                        ),
                      ),
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
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              itemCount: visible.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => ProductCard(product: visible[i]),
            ),
          ),
        ],
      ),
    );
  }

  int _discountPct(Product p) {
    final orig = p.originalPriceCents;
    if (orig == null || orig <= p.priceCents) return 0;
    return (((orig - p.priceCents) / orig) * 100).round();
  }
}
