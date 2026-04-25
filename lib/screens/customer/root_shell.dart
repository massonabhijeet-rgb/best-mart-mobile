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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSoft, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
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
                icon: Icons.refresh_rounded,
                activeIcon: Icons.refresh_rounded,
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
    final color = selected ? AppColors.brandBlue : AppColors.inkFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
