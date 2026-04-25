import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';
import 'cart_preview_sheet.dart';

/// Circular cart button that sits at the right edge of the bottom nav.
/// Always visible — when the cart is empty it just shows the bag icon;
/// when items are added a count badge animates in. Tap opens the cart
/// preview sheet (or a "your cart is empty" snackbar when empty).
class CartFab extends StatelessWidget {
  const CartFab({super.key});

  static const double _diameter = 52;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasItems = cart.totalItems > 0;
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (!hasItems) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('Your cart is empty'),
                  duration: Duration(seconds: 2),
                ));
              return;
            }
            CartPreviewSheet.show(context);
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandBlue, AppColors.brandBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 22,
              ),
              if (hasItems)
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(cart.totalItems),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
