import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/shop_status_provider.dart';
import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';
import 'quick_view_sheet.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double width;

  static const double imageHeight = 100;
  static const double contentHeight = 150;
  static const double totalHeight = imageHeight + contentHeight;

  const ProductCard({
    super.key,
    required this.product,
    this.width = 110,
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
        height: totalHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.md),
                      ),
                      child: GestureDetector(
                        onTap: () => QuickViewSheet.show(context, product),
                        child: _ProductImage(url: product.imageUrl),
                      ),
                    ),
                  ),
                  if (hasDiscount && discountPct > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        text: '$discountPct% OFF',
                        color: AppColors.brandGreen,
                      ),
                    ),
                  if (_cleanBadge)
                    Positioned(
                      top: 6,
                      left: 6,
                      right: hasDiscount && discountPct > 0 ? 72 : 6,
                      child: _Badge(
                        text: product.badge!,
                        color: AppColors.brandOrange,
                      ),
                    ),
                  const Positioned(
                    bottom: 6,
                    left: 6,
                    child: _SpeedChip(),
                  ),
                  if (lowStock)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Only ${product.stockQuantity} left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  if (outOfStock)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product.unitLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkFaint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            '₹${(product.priceCents / 100).toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text(
                                '₹${(product.originalPriceCents! / 100).toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.inkFaint,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: outOfStock
                          ? _DisabledButton()
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip();

  @override
  Widget build(BuildContext context) {
    if (context.watch<ShopStatusProvider>().isClosed) {
      return const SizedBox.shrink();
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Colors.white, size: 10),
            SizedBox(width: 2),
            Text(
              '15 min',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brSm,
            border: Border.all(color: AppColors.brandBlue, width: 1.4),
          ),
          child: const Text(
            '+ Add',
            style: TextStyle(
              color: AppColors.brandBlue,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
}

class _DisabledButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: const Text(
          'Unavailable',
          style: TextStyle(
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w700,
            fontSize: 11,
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
          color: AppColors.brandBlue,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            _StepBtn(icon: Icons.remove, onTap: onMinus),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (c, a) => ScaleTransition(
                    scale: a,
                    child: c,
                  ),
                  child: Text(
                    '$qty',
                    key: ValueKey(qty),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            _StepBtn(icon: Icons.add, onTap: onPlus),
          ],
        ),
      );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );
}
