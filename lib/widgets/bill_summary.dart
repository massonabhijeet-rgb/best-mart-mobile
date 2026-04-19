import 'package:flutter/material.dart';

import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';

class BillSummary extends StatelessWidget {
  final CartProvider cart;
  const BillSummary({super.key, required this.cart});

  String _rupees(int cents) => '₹${(cents / 100).toStringAsFixed(0)}';

  int get _productSavingsCents => cart.items.values.fold(0, (s, item) {
        final p = item.product;
        final orig = p.originalPriceCents;
        if (orig == null || orig <= p.priceCents) return s;
        return s + (orig - p.priceCents) * item.quantity;
      });

  int get _deliverySavedCents {
    final freeDelivery =
        cart.subtotalCents >= CartProvider.freeDeliveryThresholdCents;
    return freeDelivery ? CartProvider.deliveryFeeCents : 0;
  }

  int get _totalSavedCents =>
      _productSavingsCents +
      cart.promoDiscountCents +
      cart.couponDiscountCents +
      _deliverySavedCents;

  @override
  Widget build(BuildContext context) {
    final promo = cart.promoDiscountCents;
    final coupon = cart.couponDiscountCents;
    final fee = cart.deliveryFeeCentsApplied;
    final freeDelivery =
        cart.subtotalCents >= CartProvider.freeDeliveryThresholdCents;
    final saved = _totalSavedCents;

    return Column(
      children: [
        if (saved > 0) _savingsCallout(saved),
        if (saved > 0) const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadow.soft,
          ),
          child: Column(
            children: [
              _row('Subtotal', _rupees(cart.subtotalCents)),
              if (_productSavingsCents > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Item discounts',
                  '− ${_rupees(_productSavingsCents)}',
                  valueColor: AppColors.brandGreen,
                  labelIcon: Icons.percent,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _row(
                'Delivery',
                freeDelivery ? 'FREE' : _rupees(fee),
                valueColor: freeDelivery ? AppColors.brandGreen : null,
                strikeOriginal: freeDelivery ? _rupees(CartProvider.deliveryFeeCents) : null,
              ),
              if (!freeDelivery) _freeDeliveryHint(),
              if (promo > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _row(
                  '50% off promo',
                  '− ${_rupees(promo)}',
                  valueColor: AppColors.brandGreen,
                  labelIcon: Icons.celebration_outlined,
                ),
              ],
              if (coupon > 0 && cart.appliedCoupon != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Coupon (${cart.appliedCoupon!.code})',
                  '− ${_rupees(coupon)}',
                  valueColor: AppColors.brandGreen,
                  labelIcon: Icons.local_offer_outlined,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              _row(
                'To pay',
                _rupees(cart.grandTotalCents),
                bold: true,
                size: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _savingsCallout(int saved) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandGreen.withValues(alpha: 0.12),
              AppColors.brandGreen.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: AppColors.brandGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You saved ${_rupees(saved)} 🎉',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.brandGreenDark,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'on this order',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _freeDeliveryHint() {
    final away = CartProvider.freeDeliveryThresholdCents - cart.subtotalCents;
    if (away <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 12, color: AppColors.brandOrange),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Add ${_rupees(away)} more for FREE delivery',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.brandOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    double size = 14,
    Color? valueColor,
    IconData? labelIcon,
    String? strikeOriginal,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (labelIcon != null) ...[
              Icon(labelIcon, size: 14, color: AppColors.inkMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: size,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (strikeOriginal != null) ...[
              Text(
                strikeOriginal,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkFaint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
