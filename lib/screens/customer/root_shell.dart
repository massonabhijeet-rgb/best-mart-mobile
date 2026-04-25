import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/home_provider.dart';
import '../../theme/tokens.dart';
import 'categories_screen.dart';
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

  void _go(int i) {
    if (_index == i) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  void _openCategoryOnHome(int categoryId) {
    // Apply the filter and jump to the Home tab in one motion.
    context.read<HomeProvider>().setCategory(categoryId);
    _go(0);
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
      bottomNavigationBar: _BottomNav(active: _index, onTap: _go),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int active;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        // Floating pill with a hard height so the BackdropFilter has a
        // bounded surface to blur. Without the SizedBox, extendBody +
        // BackdropFilter combined to claim half the screen on iOS.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(32),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
    // No accent colour — active vs inactive shows via icon fill swap,
    // text weight, and a translucent gray highlight pill behind the
    // selected tab.
    final color = selected ? AppColors.ink : AppColors.inkFaint;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.ink.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? activeIcon : icon,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
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
