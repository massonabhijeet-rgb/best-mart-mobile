import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
import '../../widgets/cart_fab.dart';
import '../../widgets/product_card.dart';

/// Blinkit-style category browser: vertical sub-category sidebar on the
/// left + a 2-column product grid on the right. Used when the user taps
/// a category tile from the Categories tab.
class CategoryBrowserScreen extends StatefulWidget {
  final int parentCategoryId;
  const CategoryBrowserScreen({super.key, required this.parentCategoryId});

  @override
  State<CategoryBrowserScreen> createState() => _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends State<CategoryBrowserScreen> {
  final ScrollController _gridScroll = ScrollController();
  int? _selectedSubId; // null = "All" (parent itself)
  List<Product> _products = const [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _firstLoaded = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _gridScroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(reset: true));
  }

  @override
  void dispose() {
    _gridScroll.removeListener(_onScroll);
    _gridScroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_gridScroll.position.pixels >=
        _gridScroll.position.maxScrollExtent - 240) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _products = const [];
        _page = 1;
        _hasMore = true;
        _firstLoaded = false;
        _error = '';
      }
    });
    try {
      final filterId = _selectedSubId ?? widget.parentCategoryId;
      final page = await ApiService.getProductsPage(
        page: _page,
        pageSize: 20,
        categoryId: filterId,
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...page.products];
        _hasMore = page.hasMore;
        _page += 1;
        _firstLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectSub(int? id) {
    if (_selectedSubId == id) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedSubId = id);
    _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final all = home.categories;
    final parent = all.firstWhere(
      (c) => c.id == widget.parentCategoryId,
      orElse: () => Category(
        id: widget.parentCategoryId,
        name: 'Category',
        productCount: 0,
      ),
    );
    final subs = all
        .where((c) => c.parentId == widget.parentCategoryId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          parent.name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [CartFab()],
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar is shown on EVERY category page — when there are no
          // sub-categories it just contains the "All" pill, keeping the
          // layout consistent across every department the user opens.
          _Sidebar(
            subs: subs,
            selectedSubId: _selectedSubId,
            onSelect: _selectSub,
          ),
          Expanded(
            child: _MainArea(
              parent: parent,
              selectedSubName: subs
                  .where((s) => s.id == _selectedSubId)
                  .map((s) => s.name)
                  .firstOrNull,
              products: _products,
              loading: _loading,
              hasMore: _hasMore,
              firstLoaded: _firstLoaded,
              error: _error,
              scrollController: _gridScroll,
              showSidebarBanner: subs.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<Category> subs;
  final int? selectedSubId;
  final ValueChanged<int?> onSelect;
  const _Sidebar({
    required this.subs,
    required this.selectedSubId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.borderSoft, width: 0.6),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _SidebarItem(
            label: 'All',
            imageUrl: null,
            selected: selectedSubId == null,
            onTap: () => onSelect(null),
          ),
          for (final s in subs)
            _SidebarItem(
              label: s.name,
              imageUrl: s.imageUrl,
              selected: selectedSubId == s.id,
              onTap: () => onSelect(s.id),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Selection accent: green pill behind the chip + a left edge bar.
            if (selected)
              Positioned(
                left: 0,
                top: 4,
                bottom: 4,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandGreen.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.sectionSky,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandGreen
                            : AppColors.borderSoft,
                        width: selected ? 1.6 : 0.8,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.brandGreen
                                    .withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.contain,
                                memCacheWidth: 160,
                                memCacheHeight: 160,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.shopping_basket_rounded,
                                  size: 22,
                                  color: AppColors.brandBlue,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.apps_rounded,
                                size: 22,
                                color: AppColors.brandBlue,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.ink : AppColors.inkMuted,
                      height: 1.2,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainArea extends StatelessWidget {
  final Category parent;
  final String? selectedSubName;
  final List<Product> products;
  final bool loading;
  final bool hasMore;
  final bool firstLoaded;
  final String error;
  final ScrollController scrollController;
  final bool showSidebarBanner;

  const _MainArea({
    required this.parent,
    required this.selectedSubName,
    required this.products,
    required this.loading,
    required this.hasMore,
    required this.firstLoaded,
    required this.error,
    required this.scrollController,
    required this.showSidebarBanner,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _Banner(
            title: selectedSubName ?? parent.name,
            subtitle: selectedSubName == null
                ? 'Explore everything in ${parent.name}'
                : 'Handpicked from ${parent.name}',
            imageUrl: parent.imageUrl,
          ),
        ),
        if (!firstLoaded)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(error: error),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            sliver: SliverGrid.builder(
              // mainAxisExtent pins each tile's height to the card's
              // actual rendered size. Using `childAspectRatio` instead
              // stretched tiles to fit the (wider-than-storefront) 2-col
              // grid, leaving 50-80px of empty white space below the
              // product name.
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                mainAxisExtent: 230,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(
                product: products[i],
                width: double.infinity,
              ),
            ),
          ),
          if (loading && hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  const _Banner({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandGreen.withValues(alpha: 0.16),
            AppColors.brandGreen.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.brandGreen.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (imageUrl != null && imageUrl!.isNotEmpty)
            SizedBox(
              width: 70,
              height: 70,
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.contain,
                memCacheWidth: 220,
                memCacheHeight: 220,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String error;
  const _EmptyState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error.isNotEmpty
                ? Icons.error_outline_rounded
                : Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.inkFaint,
          ),
          const SizedBox(height: 12),
          Text(
            error.isNotEmpty
                ? 'Couldn’t load products'
                : 'Nothing here yet',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
