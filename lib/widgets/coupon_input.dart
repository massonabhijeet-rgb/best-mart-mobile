import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';

class CouponInput extends StatefulWidget {
  const CouponInput({super.key});

  @override
  State<CouponInput> createState() => _CouponInputState();
}

class _CouponInputState extends State<CouponInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final cart = context.read<CartProvider>();
    final ok = await cart.applyCoupon(_ctrl.text);
    if (ok) _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final applied = cart.appliedCoupon;

    if (applied != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.brandGreen.withValues(alpha: 0.08),
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: AppColors.brandGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.brandGreen, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coupon ${applied.code} applied',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandGreenDark,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '− ₹${(applied.discountCents / 100).toStringAsFixed(0)}'
                    '${applied.description != null ? '  ·  ${applied.description}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: cart.clearCoupon,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  prefixIcon: const Icon(Icons.local_offer_outlined,
                      color: AppColors.inkFaint, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.brMd,
                    borderSide: BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brMd,
                    borderSide: BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brMd,
                    borderSide: const BorderSide(
                        color: AppColors.brandBlue, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: cart.applyingCoupon ? null : _apply,
                child: cart.applyingCoupon
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandBlue,
                        ),
                      )
                    : const Text('Apply'),
              ),
            ),
          ],
        ),
        if (cart.couponError.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            cart.couponError,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
