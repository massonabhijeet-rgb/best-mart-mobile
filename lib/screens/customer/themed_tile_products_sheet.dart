import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
import 'cart_provider.dart';

/// Bottom-sheet drill-down opened when a customer taps a tile inside
/// a themed page. Fetches products that match the tile's link target
/// (category id / search query / product ids) and renders them in a
/// 2-col grid — same product-card chrome as the Order Again sheet so
/// add-to-cart works identically.
///
/// Designed to keep the customer "on" the themed page (the sheet
/// dismisses straight back to it) rather than navigating away to the
/// global storefront grid.
class ThemedTileProductsSheet extends StatefulWidget {
  final ThemedPageTile tile;
  const ThemedTileProductsSheet({super.key, required this.tile});

  static Future<void> show({
    required BuildContext context,
    required ThemedPageTile tile,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => ThemedTileProductsSheet(tile: tile),
    );
  }

  @override
  State<ThemedTileProductsSheet> createState() =>
      _ThemedTileProductsSheetState();
}

class _ThemedTileProductsSheetState extends State<ThemedTileProductsSheet> {
  bool _loading = true;
  String? _error;
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tile = widget.tile;
    try {
      ProductPage page;
      switch (tile.linkType) {
        case ThemedPageTileLinkType.category:
          page = await ApiService.getProductsPage(
            page: 1,
            pageSize: 40,
            categoryId: tile.linkCategoryId,
          );
          break;
        case ThemedPageTileLinkType.search:
          page = await ApiService.getProductsPage(
            page: 1,
            pageSize: 40,
            search: tile.linkSearchQuery,
          );
          break;
        case ThemedPageTileLinkType.productIds:
        case ThemedPageTileLinkType.unknown:
          // No "list-of-N-product-ids" surface yet; show empty state.
          page = ProductPage(
            products: const [],
            total: 0,
            page: 1,
            pageSize: 0,
            hasMore: false,
          );
          break;
      }
      if (!mounted) return;
      setState(() {
        _products = page.products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        // Close button now lives INSIDE the sheet at the top-right
        // corner so it never collides with the iPhone notch when the
        // sheet starts at 92% (top edge ends up under the dynamic-
        // island area).
        //
        // Liquid-glass surface: ClipRRect + BackdropFilter blurs
        // whatever's behind the sheet (visible while the user drags
        // the sheet down) and a translucent surface tint gives the
        // top of the sheet that frosted look matching the rest of the
        // app's glass treatment.
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            children: [
              // Drag handle — small grey pill at the top so the swipe-
              // down-to-dismiss affordance is visible.
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
                        widget.tile.label,
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
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandBlue,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.inkFaint,
                                ),
                              ),
                            ),
                          )
                        : _products.isEmpty
                            ? const Center(
                                child: Text(
                                  'No products yet.',
                                  style:
                                      TextStyle(color: AppColors.inkFaint),
                                ),
                              )
                            : GridView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                    12, 4, 12, 24),
                                itemCount: _products.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.62,
                                ),
                                itemBuilder: (_, i) => _GridProductCard(
                                  product: _products[i],
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
              border: Border.all(color: AppColors.brandGreen, width: 1.4),
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
