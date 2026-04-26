import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/shop_status_provider.dart';
import '../screens/customer/cart_provider.dart';
import '../screens/customer/checkout_screen.dart';
import '../theme/tokens.dart';

class CartPreviewSheet extends StatelessWidget {
  const CartPreviewSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartPreviewSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shop = context.watch<ShopStatusProvider>();
    final items = cart.items.values.toList();
    final freeThreshold = CartProvider.freeDeliveryThresholdCents;
    final remaining = freeThreshold - cart.subtotalCents;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      // Liquid-glass surface — ClipRRect rounds the top, BackdropFilter
      // blurs anything visible behind the sheet (esp. while it's being
      // dragged down past the storefront's drifting blob backdrop), and
      // the surface is translucent so the colors come through. Mirrors
      // the themed-tile sheet for consistency.
      builder: (ctx, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.pageBg.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inkFaint.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppColors.brandBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your cart',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cart.totalItems} ${cart.totalItems == 1 ? "item" : "items"} · ₹${(cart.subtotalCents / 100).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.inkFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.inkMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            if (remaining > 0 && cart.subtotalCents > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.08),
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: AppColors.brandGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 16, color: AppColors.brandGreenDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Add ₹${(remaining / 100).toStringAsFixed(0)} more for FREE delivery',
                          style: const TextStyle(
                            color: AppColors.brandGreenDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (cart.subtotalCents >= freeThreshold)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    borderRadius: AppRadius.brMd,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppColors.brandGreenDark),
                      SizedBox(width: 6),
                      Text(
                        'FREE delivery unlocked',
                        style: TextStyle(
                          color: AppColors.brandGreenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: AppSpacing.md, thickness: 0.6),
            Expanded(
              child: items.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: AppSpacing.md,
                        thickness: 0.5,
                      ),
                      itemBuilder: (_, i) => _Line(item: items[i]),
                    ),
            ),
            if (items.isNotEmpty)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.borderSoft),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹${(cart.subtotalCents / 100).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: shop.isClosed
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CheckoutScreen(),
                                      ),
                                    );
                                  },
                            borderRadius: AppRadius.brMd,
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: shop.isClosed
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF9CA3AF),
                                          Color(0xFF6B7280),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [
                                          AppColors.brandBlue,
                                          AppColors.brandBlueDark,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: AppRadius.brMd,
                                boxShadow: shop.isClosed
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.brandBlue
                                              .withValues(alpha: 0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      shop.isClosed
                                          ? 'Store closed'
                                          : 'Go to checkout',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
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
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: AppColors.inkFaint.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Your cart is empty',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Line extends StatelessWidget {
  final CartItem item;
  const _Line({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final p = item.product;
    final lineTotal = p.priceCents * item.quantity;
    return Row(
      children: [
        ClipRRect(
          borderRadius: AppRadius.brSm,
          child: SizedBox(
            width: 52,
            height: 52,
            child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    memCacheHeight: 160,
                    errorWidget: (_, __, ___) => _fallback(),
                    placeholder: (_, __) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.unitLabel,
                style: const TextStyle(
                  color: AppColors.inkFaint,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${(lineTotal / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.brandBlue,
            borderRadius: AppRadius.brSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(Icons.remove, () => cart.remove(p.uniqueId)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              _btn(Icons.add, () => cart.add(p)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _fallback() => Container(
        color: AppColors.sectionSky,
        child: const Icon(Icons.shopping_basket,
            size: 22, color: AppColors.brandBlue),
      );
}
