import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';
import 'cart_preview_sheet.dart';

/// Compact floating cart pill: bag icon + count badge + total. Slides in
/// when the cart has items. Tap opens the cart preview sheet. Lives in
/// the root shell (above the bottom nav) so it overlays cleanly without
/// fighting the floating nav pill at the same y-position.
class CartFab extends StatelessWidget {
  const CartFab({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final visible = cart.totalItems > 0;
    // AnimatedSize collapses the slot to zero height when the cart is
    // empty so the nav pill below sits flush against the bottom edge,
    // and the pill smoothly slides in/out when items appear/disappear.
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomLeft,
      child: !visible
          ? const SizedBox.shrink()
          : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () {
                HapticFeedback.lightImpact();
                CartPreviewSheet.show(context);
              },
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandBlue, AppColors.brandBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: Container(
                                key: ValueKey(cart.totalItems),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(
                                    minWidth: 15, minHeight: 15),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.brandOrange,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  border: Border.all(
                                      color: Colors.white, width: 1.2),
                                ),
                                child: Text(
                                  '${cart.totalItems}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          '₹${(cart.subtotalCents / 100).toStringAsFixed(0)}',
                          key: ValueKey(cart.subtotalCents),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
