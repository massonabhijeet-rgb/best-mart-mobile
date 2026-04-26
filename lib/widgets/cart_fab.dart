import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/customer/cart_provider.dart';
import '../theme/tokens.dart';
import 'cart_preview_sheet.dart';

/// Circular cart button at the right edge of the bottom nav. Always
/// visible — when the cart is empty the bag icon shows alone, on add
/// a count badge animates in. A "pulse ring" fires a one-shot scale +
/// fade outward whenever the total item count goes up so the user gets
/// a positive visual confirmation that the add landed.
class CartFab extends StatefulWidget {
  const CartFab({super.key});

  static const double _diameter = 52;

  @override
  State<CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<CartFab> with TickerProviderStateMixin {
  // Pulse ring animation — fires every time totalItems increases.
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  // Soft button "press" pulse — same trigger, smaller scale, on the
  // button itself so it feels like the cart "pops" on add.
  late final AnimationController _bumpCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  int _lastCount = 0;
  // Skip the pulse on the very first observed value — that's the
  // initial render of the widget (e.g. the user already had items
  // in their cart from a prior session). The pulse should only fire
  // on a real, in-app add.
  bool _initialized = false;

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bumpCtrl.dispose();
    super.dispose();
  }

  void _maybeFirePulse(int newCount) {
    if (_initialized && newCount > _lastCount) {
      // Schedule for the next frame so we don't fire during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pulseCtrl.forward(from: 0);
        _bumpCtrl.forward(from: 0).then((_) {
          if (mounted) _bumpCtrl.reverse();
        });
      });
    }
    _lastCount = newCount;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasItems = cart.totalItems > 0;
    _maybeFirePulse(cart.totalItems);

    return SizedBox(
      width: CartFab._diameter,
      height: CartFab._diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pulse ring — sits behind the button, scales out and fades
          // every time _pulseCtrl fires.
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              if (_pulseCtrl.value == 0) return const SizedBox.shrink();
              final t = _pulseCtrl.value;
              final scale = 1.0 + 0.45 * t;
              final opacity = (1 - t).clamp(0.0, 1.0);
              return IgnorePointer(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: CartFab._diameter,
                    height: CartFab._diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandBlue.withValues(alpha: 0.5 * opacity),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _bumpCtrl,
            builder: (context, child) {
              // _bumpCtrl: 0 -> 1 -> 0; map to a 1.0 -> 1.08 -> 1.0
              // scale curve so the cart "pops" briefly on add.
              final scale = 1.0 + 0.08 * _bumpCtrl.value;
              return Transform.scale(scale: scale, child: child);
            },
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
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
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
          ),
        ],
      ),
    );
  }
}
