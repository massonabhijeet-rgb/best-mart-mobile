import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/active_order_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/active_order_ribbon.dart';
import '../../widgets/cart_fab.dart';
import 'cart_provider.dart';
import 'categories_screen.dart';
import 'category_browser_screen.dart';
import 'order_again_screen.dart';
import 'storefront_screen.dart';

/// Bottom-nav shell that hosts the three customer tabs (Home,
/// Order Again, Categories). State is preserved via IndexedStack so
/// switching tabs doesn't reload rails or scroll position.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Load active orders the moment the user lands on the customer shell
    // (after a fresh login, the cold-start `auth.isLoggedIn` check in
    // main.dart was already false-then-true). Safe to call repeatedly —
    // the provider guards against duplicate fetches.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActiveOrderProvider>().load();
    });
  }

  void _go(int i) {
    if (_index == i) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  void _openCategoryOnHome(int categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CategoryBrowserScreen(parentCategoryId: categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body extends behind the floating nav so content scrolls under
      // the frosted pill instead of getting cropped by a solid bar.
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          const StorefrontScreen(),
          const OrderAgainScreen(),
          CategoriesScreen(onCategoryTap: _openCategoryOnHome),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        // Bottom inset trimmed: the system home-indicator gives ~34pt of
        // safe area on its own; we don't need an extra 6pt cushion above
        // it. Setting `minimum: zero` and shrinking the inner padding to
        // 0 lets the floating nav sit ~6pt closer to the screen edge.
        minimum: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ribbon sits above the floating nav so it never overlaps the
            // tabs or the cart FAB; auto-hides itself when no order is
            // in progress.
            const ActiveOrderRibbon(),
            // Cart FAB disappears entirely when the cart is empty —
            // empty-state shouldn't surface a button that, on tap, would
            // just say "your cart is empty". When the user adds the first
            // item, the FAB animates in with the nav re-laying out around it.
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                final hasItems = cart.totalItems > 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _BottomNav(active: _index, onTap: _go)),
                      if (hasItems) ...[
                        const SizedBox(width: 10),
                        const CartFab(),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int active;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Hard height so the BackdropFilter has a bounded surface to blur.
    return SizedBox(
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          // Liquid-glass treatment: stronger sigma + lower opacity so
          // the storefront's drifting blob colors show through, same
          // dial as the app bar.
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.borderSoft.withValues(alpha: 0.7),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  selected: active == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  label: 'Order Again',
                  icon: Icons.shopping_bag_outlined,
                  activeIcon: Icons.shopping_bag_rounded,
                  selected: active == 1,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  label: 'Categories',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  selected: active == 2,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected tab: a brighter white pill behind a colored icon, bolded
    // label. Mirrors the Blinkit-style nav reference.
    final iconColor =
        selected ? AppColors.brandOrange : AppColors.inkFaint;
    final labelColor = selected ? AppColors.ink : AppColors.inkFaint;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color:
              selected ? Colors.white.withValues(alpha: 0.95) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? activeIcon : icon,
                    size: 18,
                    color: iconColor,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                      color: labelColor,
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
