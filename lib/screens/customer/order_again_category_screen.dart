import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../theme/tokens.dart';
import 'cart_provider.dart';

/// Bottom-sheet drill-down from an Order-Again tile. Shows the
/// products the user has already bought in that category as a 2-col
/// grid of large cards. Lifts the most prominent product chrome from
/// the storefront — image card with the weight chip + an ADD button
/// hanging off the bottom-right edge — without piling on signals we
/// don't yet capture (ratings, "trending" badges, etc).
class OrderAgainCategorySheet extends StatelessWidget {
  final String categoryName;
  final List<Product> products;
  const OrderAgainCategorySheet({
    super.key,
    required this.categoryName,
    required this.products,
  });

  /// Use this instead of constructing the widget directly — it wraps
  /// the sheet in showModalBottomSheet with the right shape + scroll
  /// affordances.
  static Future<void> show({
    required BuildContext context,
    required String categoryName,
    required List<Product> products,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => OrderAgainCategorySheet(
        categoryName: categoryName,
        products: products,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        // Notch-safe + liquid-glass: close button lives INSIDE the
        // sheet (top-right of the title row) so it never collides with
        // the iPhone notch when the sheet starts at 92%. The whole
        // sheet sits behind a BackdropFilter so the storefront's
        // drifting blob backdrop refracts through it while the sheet
        // is being dragged down — same family as the themed-tile and
        // cart preview sheets.
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle.
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        Material(
                          color: const Color(0x14101828),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                color: AppColors.ink,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      itemBuilder: (_, i) => _GridProductCard(
                        product: products[i],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridProductCard extends StatelessWidget {
  final Product product;
  const _GridProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantity(product.uniqueId);
    final inStock = product.stockQuantity > 0;

    final mrp = product.originalPriceCents;
    final price = product.priceCents;
    final discountPct = (mrp != null && mrp > price)
        ? ((mrp - price) * 100 / mrp).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Image card with weight chip + Add button overlap ──
        Stack(
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                padding: const EdgeInsets.all(8),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: 320,
                        memCacheHeight: 320,
                        placeholder: (_, __) => const SizedBox.shrink(),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.inkFaint,
                          size: 32,
                        ),
                      ),
              ),
            ),
            if (!inStock)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1F2937),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    'Out of stock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  product.unitLabel,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Add button overlaps the bottom-right edge of the image card.
            Positioned(
              right: -2,
              bottom: -10,
              child: _AddButton(
                product: product,
                qty: qty,
                inStock: inStock,
                onAdd: () => cart.add(product),
                onRemove: () => cart.remove(product.uniqueId),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '₹${(price / 100).toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            if (mrp != null && mrp > price) ...[
              const SizedBox(width: 6),
              Text(
                '₹${(mrp / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkFaint,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (discountPct > 0) ...[
          const SizedBox(height: 1),
          Text(
            '$discountPct% OFF',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.brandBlue,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          product.name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final Product product;
  final int qty;
  final bool inStock;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _AddButton({
    required this.product,
    required this.qty,
    required this.inStock,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (!inStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.brandGreen, width: 1.4),
          boxShadow: AppShadow.soft,
        ),
        child: const Text(
          'Notify',
          style: TextStyle(
            color: AppColors.brandGreen,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    if (qty == 0) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        elevation: 0,
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
                  Border.all(color: AppColors.brandGreen, width: 1.4),
              boxShadow: AppShadow.soft,
            ),
            child: const Text(
              'ADD',
              style: TextStyle(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandGreen,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove, color: Colors.white, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
