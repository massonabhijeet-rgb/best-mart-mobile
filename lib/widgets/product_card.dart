import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';
import 'quick_view_sheet.dart';

/// Zepto/Blinkit-style product card: flat white surface with thin border,
/// image area on top with a weight chip at the bottom-left and a floating
/// ADD button at the bottom-right (overlapping the image / content
/// boundary), and a price-first content section below — price big and
/// bold, discount % in brand-blue, product name 2 lines below.
class ProductCard extends StatelessWidget {
  final Product product;
  final double width;

  static const double imageHeight = 130;
  static const double contentHeight = 130;
  static const double totalHeight = imageHeight + contentHeight;

  const ProductCard({
    super.key,
    required this.product,
    this.width = 150,
  });

  bool get _cleanBadge {
    final b = product.badge;
    if (b == null || b.isEmpty) return false;
    if (b.contains(',')) return false;
    if (b.length > 16) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantity(product.uniqueId);
    final hasDiscount = product.originalPriceCents != null &&
        product.originalPriceCents! > product.priceCents;
    final discountPct = hasDiscount
        ? (((product.originalPriceCents! - product.priceCents) /
                    product.originalPriceCents!) *
                100)
            .round()
        : 0;
    final outOfStock = product.stockQuantity <= 0;
    final lowStock = product.stockQuantity > 0 && product.stockQuantity <= 5;

    return Opacity(
      opacity: outOfStock ? 0.55 : 1,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.borderSoft,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image area with weight chip + floating ADD button ──
            SizedBox(
              height: imageHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Subtle inner background so the cutout image has
                  // depth instead of sitting on a flat panel.
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: GestureDetector(
                          onTap: () => QuickViewSheet.show(context, product),
                          child: _ProductImage(url: product.imageUrl),
                        ),
                      ),
                    ),
                  ),
                  // Custom badge top-left (if it's a clean short string).
                  if (_cleanBadge)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(
                        text: product.badge!,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  // Out-of-stock overlay covers the image entirely.
                  if (outOfStock)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.lg),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Weight chip pinned bottom-left of the image.
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        product.unitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                  // Low-stock chip below the weight chip — only shown
                  // when stock is 1-5. Doesn't fight the ADD button
                  // because we anchor it to the LEFT of the image.
                  if (lowStock)
                    Positioned(
                      left: 8,
                      bottom: 36,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${product.stockQuantity} left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  // Floating ADD button — overlaps the bottom-right of
                  // the image area. Negative bottom anchor so it
                  // straddles the image / content boundary like the
                  // reference design.
                  Positioned(
                    right: 8,
                    bottom: -12,
                    child: SizedBox(
                      width: 70,
                      height: 32,
                      child: outOfStock
                          ? const _DisabledButton()
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOutBack,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (c, a) => ScaleTransition(
                                scale: a,
                                child: c,
                              ),
                              child: qty == 0
                                  ? _AddButton(
                                      key: const ValueKey('add'),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        cart.add(product);
                                      },
                                    )
                                  : _QtyStepper(
                                      key: const ValueKey('stepper'),
                                      qty: qty,
                                      onMinus: () {
                                        HapticFeedback.selectionClick();
                                        cart.remove(product.uniqueId);
                                      },
                                      onPlus: () {
                                        HapticFeedback.selectionClick();
                                        cart.add(product);
                                      },
                                    ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Content area: price-first, then discount, then name ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(product.priceCents / 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '₹${(product.originalPriceCents! / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.inkFaint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasDiscount && discountPct > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$discountPct% OFF on MRP',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.contain,
      memCacheWidth: 400,
      memCacheHeight: 400,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => Container(
        color: AppColors.surfaceSoft,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.sectionSky,
        child: const Icon(
          Icons.shopping_basket_rounded,
          size: 36,
          color: AppColors.brandBlue,
        ),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brSm,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brSm,
              border:
                  Border.all(color: AppColors.brandGreen, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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

class _DisabledButton extends StatelessWidget {
  const _DisabledButton();

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: const Text(
          'Notify',
          style: TextStyle(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    super.key,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.brandGreen,
          borderRadius: AppRadius.brSm,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandGreen.withValues(alpha: 0.32),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onMinus,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onPlus,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
}
