import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../providers/shop_status_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_strip.dart';
import '../../widgets/cart_preview_sheet.dart';
import '../../widgets/category_tiles_grid.dart';
import '../../widgets/home_rail.dart';
import '../../widgets/product_card.dart';
import '../../widgets/section_background.dart';
import '../../widgets/skeleton.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';
import 'profile_screen.dart';

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});
  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;
  Timer? _hintRotator;
  int _hintIndex = 0;

  // Popup overlay is shown at most once per app session.
  static bool _campaignShownThisSession = false;
  int? _lastCampaignSeenId;

  static const List<String> _searchHints = [
    'Search "milk"',
    'Search "bread"',
    'Search "eggs"',
    'Search "chips"',
    'Search "atta"',
    'Search "chocolate"',
  ];

  static const List<_RailTheme> _railThemes = [
    _RailTheme(emoji: '⭐', tint: SectionTint.yellow),
    _RailTheme(emoji: '☀️', tint: SectionTint.peach),
    _RailTheme(emoji: '🥬', tint: SectionTint.mint),
    _RailTheme(emoji: '🛒', tint: SectionTint.sky),
    _RailTheme(emoji: '🍫', tint: SectionTint.lavender),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadHome();
    });
    _hintRotator = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _searchHints.length);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _hintRotator?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final home = context.read<HomeProvider>();
    if (!home.isFiltered) return;
    if (!home.hasMore || home.loadingMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      home.loadMore();
    }
  }

  void _maybeShowCampaignPopup(HomeProvider home) {
    final c = home.activeCampaign;
    if (c == null || c.imageUrl == null || c.imageUrl!.isEmpty) return;
    if (_campaignShownThisSession) return;
    if (_lastCampaignSeenId == c.id) return;
    _lastCampaignSeenId = c.id;
    _campaignShownThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (dialogCtx) => _CampaignOverlay(
          campaign: c,
          onCategoryTap: (categoryId) {
            Navigator.of(dialogCtx).pop();
            context.read<HomeProvider>().setCategory(categoryId);
            _scrollCtrl.animateTo(
              0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          },
          onClose: () => Navigator.of(dialogCtx).pop(),
        ),
      ).then((_) {
        if (mounted) {
          context.read<HomeProvider>().consumeActiveCampaign();
        }
      });
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<HomeProvider>().setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final home = context.watch<HomeProvider>();
    final shop = context.watch<ShopStatusProvider>();

    _maybeShowCampaignPopup(home);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      extendBodyBehindAppBar: true,
      appBar: _appBar(cart),
      body: Container(
        // Soft brand-blue gradient gives the page a sense of depth without
        // changing the palette; cards float over a tinted surface so the
        // frosted-glass top bar has something interesting to blur.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE1ECFD),
              Color(0xFFEDF2FF),
              Color(0xFFF7F9FF),
            ],
            stops: [0, 0.35, 1],
          ),
        ),
        // Manually inset for status bar + AppBar height because the
        // body extends behind the frosted-glass bar.
        child: Column(
          children: [
            SizedBox(
              height:
                  MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
            if (shop.isClosed) _ShopClosedBanner(message: shop.closedMessage),
            Expanded(child: _body(home)),
          ],
        ),
      ),
      floatingActionButton: _CartFab(cart: cart),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _appBar(CartProvider cart) => AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.62),
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0x14101828),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                borderRadius: AppRadius.brSm,
              ),
              child: const Icon(
                Icons.shopping_basket_rounded,
                color: AppColors.brandBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'BestMart',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.ink),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined,
                    color: AppColors.ink),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
              ),
              if (cart.totalItems > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${cart.totalItems}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      );

  Widget _body(HomeProvider home) {
    if (home.state == LoadState.loading && home.rails == null) {
      return const HomeSkeleton();
    }
    if (home.state == LoadState.error && home.rails == null) {
      return _ErrorView(message: home.error, onRetry: home.refresh);
    }
    return RefreshIndicator(
      onRefresh: home.refresh,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          const SliverToBoxAdapter(child: _DeliveryHeader()),
          const SliverToBoxAdapter(child: _ContextBanner()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSearchBarDelegate(
              child: _searchBar(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverToBoxAdapter(child: _categoryChips(home)),
          if (home.isFiltered)
            ..._buildFilteredSlivers(home, context)
          else
            ..._buildHomeSlivers(home),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: _searchCtrl.text.isEmpty ? ' ' : null,
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.inkMuted,
                  size: 22,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.inkMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<HomeProvider>().setSearch('');
                          setState(() {});
                        },
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.mic_none_rounded,
                          color: AppColors.inkMuted,
                          size: 20,
                        ),
                        tooltip: 'Voice search (coming soon)',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voice search coming soon'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: AppColors.borderSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: AppColors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(
                    color: AppColors.brandBlue,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_searchCtrl.text.isEmpty)
              Positioned(
                left: 48,
                right: 48,
                child: IgnorePointer(
                  child: Text(
                    _searchHints[_hintIndex],
                    style: const TextStyle(
                      color: AppColors.inkFaint,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _categoryChips(HomeProvider home) {
    if (home.categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0, 0.04, 0.94, 1],
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: [
            _CatChip(
              label: 'All',
              icon: '✨',
              selected: home.categoryId == null,
              onTap: () => home.setCategory(null),
            ),
            ...home.categories.map(
              (c) => _CatChip(
                label: c.name,
                icon: _emojiForCategory(c.name),
                selected: home.categoryId == c.id,
                onTap: () =>
                    home.setCategory(home.categoryId == c.id ? null : c.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _emojiForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) return '🥬';
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg')) {
      return '🥛';
    }
    if (n.contains('bread') || n.contains('bakery')) return '🍞';
    if (n.contains('meat') || n.contains('chicken') || n.contains('fish')) {
      return '🍗';
    }
    if (n.contains('snack') || n.contains('chip')) return '🍿';
    if (n.contains('drink') || n.contains('bever') || n.contains('juice')) {
      return '🥤';
    }
    if (n.contains('choco') || n.contains('sweet') || n.contains('candy')) {
      return '🍫';
    }
    if (n.contains('personal') || n.contains('care') || n.contains('beauty')) {
      return '🧴';
    }
    if (n.contains('home') || n.contains('clean') || n.contains('house')) {
      return '🧼';
    }
    if (n.contains('frozen') || n.contains('ice')) return '🧊';
    if (n.contains('rice') || n.contains('atta') || n.contains('flour') ||
        n.contains('grain')) {
      return '🌾';
    }
    if (n.contains('oil') || n.contains('ghee')) return '🫙';
    if (n.contains('tea') || n.contains('coffee')) return '☕';
    if (n.contains('baby') || n.contains('kid')) return '🍼';
    if (n.contains('pet')) return '🐶';
    return '🛒';
  }

  String _bestsellerTitle() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return 'Breakfast essentials';
    if (h >= 11 && h < 16) return 'Lunch picks';
    if (h >= 16 && h < 21) return 'Dinner ready in 15';
    return 'Late-night cravings';
  }

  String _bestsellerSubtitle() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return 'Start your morning right';
    if (h >= 11 && h < 16) return 'Quick bites and fresh picks';
    if (h >= 16 && h < 21) return 'Tonight\'s dinner, delivered fast';
    return 'Snacks and staples for tonight';
  }

  List<CategoryRail> _prioritizedRails(List<CategoryRail> rails) {
    final indexed = rails.asMap().entries.toList();
    indexed.sort((a, b) {
      final pa = _categoryPriority(a.value.name);
      final pb = _categoryPriority(b.value.name);
      if (pa != pb) return pa.compareTo(pb);
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  int _categoryPriority(String name) {
    final n = name.toLowerCase();
    final h = DateTime.now().hour;
    final day = DateTime.now().weekday;
    final isWeekend = day == DateTime.saturday || day == DateTime.sunday;

    List<String> topKeywords;
    if (isWeekend) {
      topKeywords = ['snack', 'chip', 'choco', 'sweet', 'drink', 'bever',
          'frozen', 'ice'];
    } else if (h >= 5 && h < 11) {
      topKeywords = ['dairy', 'milk', 'egg', 'bread', 'bakery', 'tea',
          'coffee', 'fruit', 'cereal', 'oats'];
    } else if (h >= 11 && h < 16) {
      topKeywords = ['rice', 'atta', 'flour', 'grain', 'veg', 'fruit', 'oil',
          'ghee', 'dal'];
    } else if (h >= 16 && h < 21) {
      topKeywords = ['snack', 'veg', 'meat', 'chicken', 'frozen', 'bread',
          'rice'];
    } else {
      topKeywords = ['snack', 'chip', 'choco', 'ice', 'drink', 'bever'];
    }
    for (final k in topKeywords) {
      if (n.contains(k)) return 0;
    }
    return 1;
  }

  String _bestsellerEmoji() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return '🌅';
    if (h >= 11 && h < 16) return '☀️';
    if (h >= 16 && h < 21) return '🌇';
    return '🌙';
  }

  List<Widget> _buildHomeSlivers(HomeProvider home) {
    final rails = home.rails;
    if (rails == null) return const [];
    final slivers = <Widget>[];

    void addGap() => slivers.add(const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.sm),
        ));

    final spot = home.spotlight;
    if (spot != null && spot.offerProducts.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: "Today's deals",
          subtitle: 'Hand-picked offers, just for today',
          emoji: '🔥',
          tint: SectionTint.peach,
          products: spot.offerProducts,
        ),
      ));
      addGap();
    }

    for (var i = 0; i < home.tempCategories.length; i++) {
      final tc = home.tempCategories[i];
      if (tc.products.isEmpty) continue;
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: tc.name,
          subtitle: '${tc.products.length} pick${tc.products.length == 1 ? '' : 's'} this week',
          emoji: _themeEmoji(tc.theme),
          tint: _themeTint(tc.theme),
          products: tc.products,
        ),
      ));
      addGap();
    }

    if (spot != null && spot.moodPicks.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: 'Picked for today',
          subtitle: 'Matched to the weather and the clock',
          emoji: '🌤️',
          tint: SectionTint.sky,
          products: spot.moodPicks,
        ),
      ));
      addGap();
    }

    if (spot != null && spot.dailyEssentials.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: 'Buy these on repeat',
          subtitle: 'The staples your kitchen runs on',
          emoji: '🛒',
          tint: SectionTint.mint,
          products: spot.dailyEssentials,
        ),
      ));
      addGap();
    }

    if (rails.bestsellers.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: _bestsellerTitle(),
          subtitle: _bestsellerSubtitle(),
          emoji: _bestsellerEmoji(),
          tint: _railThemes[0].tint,
          products: rails.bestsellers,
        ),
      ));
      addGap();
    }

    final isClosed = context.read<ShopStatusProvider>().isClosed;
    final ordered = _prioritizedRails(rails.categoryRails);
    for (var i = 0; i < ordered.length; i++) {
      final rail = ordered[i];
      if (rail.products.isEmpty) continue;
      final theme = _railThemes[(i + 1) % _railThemes.length];
      final subtitle = isClosed
          ? '${rail.products.length}+ picks'
          : '${rail.products.length}+ picks · delivered in 15 min';
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: 'Top in ${rail.name}',
          subtitle: subtitle,
          emoji: theme.emoji,
          tint: theme.tint,
          products: rail.products,
          onSeeAll: () => home.setCategory(rail.id),
        ),
      ));
      addGap();
    }

    if (home.categories.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: CategoryTilesGrid(
          categories: home.categories,
          onTap: (id) => home.setCategory(id),
        ),
      ));
    }

    if (home.brands.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: BrandStrip(
          brands: home.brands,
          onTap: (b) => home.setBrand(b.name),
        ),
      ));
    }

    if (slivers.isEmpty) {
      slivers.add(const SliverToBoxAdapter(
        child: _EmptyView(
          icon: Icons.storefront_outlined,
          title: 'Shelves are being stocked',
          message: 'New arrivals will show up here soon.',
        ),
      ));
    }
    return slivers;
  }

  String _themeEmoji(String theme) {
    switch (theme) {
      case 'summer':
        return '☀️';
      case 'winter':
        return '❄️';
      case 'monsoon':
        return '🌧️';
      case 'holi':
        return '🎨';
      case 'rakhi':
        return '🎀';
      case 'independence':
      case 'republic':
        return '🇮🇳';
      case 'ganesh':
        return '🕉️';
      case 'navratri':
        return '💃';
      case 'diwali':
        return '🪔';
      case 'christmas':
        return '🎄';
      case 'newyear':
        return '🎉';
      default:
        return '✨';
    }
  }

  SectionTint _themeTint(String theme) {
    switch (theme) {
      case 'summer':
      case 'holi':
      case 'diwali':
        return SectionTint.peach;
      case 'winter':
      case 'christmas':
        return SectionTint.sky;
      case 'monsoon':
        return SectionTint.mint;
      case 'rakhi':
      case 'navratri':
        return SectionTint.lavender;
      default:
        return SectionTint.yellow;
    }
  }

  List<Widget> _buildFilteredSlivers(HomeProvider home, BuildContext context) {
    if (!home.firstGridLoaded && home.gridProducts.isEmpty) {
      return [_skeletonGrid()];
    }
    if (home.firstGridLoaded && home.gridProducts.isEmpty) {
      final searching = home.search.isNotEmpty;
      return [
        SliverToBoxAdapter(
          child: _EmptyView(
            icon: searching ? Icons.search_off : Icons.category_outlined,
            title: searching
                ? 'No matches for "${home.search}"'
                : 'Nothing here yet',
            message: searching
                ? 'Try a different word, or browse popular categories below.'
                : 'This category is being restocked — check back soon.',
            actionLabel: searching ? 'Clear search' : null,
            onAction: searching
                ? () {
                    _searchCtrl.clear();
                    home.setSearch('');
                  }
                : null,
          ),
        ),
      ];
    }
    return [
      _productGrid(home.gridProducts),
      if (home.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ),
        ),
      if (!home.hasMore && home.gridProducts.isNotEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                "You've reached the end.",
                style: TextStyle(color: AppColors.inkFaint, fontSize: 12),
              ),
            ),
          ),
        ),
    ];
  }

  int _gridColumnCount() {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 1100
        ? 6
        : width >= 900
            ? 5
            : width >= 600
                ? 4
                : width >= 380
                    ? 3
                    : 2;
  }

  Widget _skeletonGrid() {
    final count = _gridColumnCount();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisExtent: ProductCard.totalHeight,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) =>
              const Shimmer(child: ProductCardSkeleton(width: double.infinity)),
          childCount: count * 2,
        ),
      ),
    );
  }

  Widget _productGrid(List<Product> items) {
    final count = _gridColumnCount();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisExtent: ProductCard.totalHeight,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductCard(product: items[i], width: double.infinity),
          childCount: items.length,
        ),
      ),
    );
  }
}

// Pins the search bar to the top of the scroll viewport once the
// delivery header + context banner scroll past. Background is fully
// transparent at rest (so the bar sits naturally on the gradient) and
// fades to a solid white surface with a hairline bottom border once
// pinned — keeps the input readable without piling on shadows or blur.
class _PinnedSearchBarDelegate extends SliverPersistentHeaderDelegate {
  static const double _height = 64;
  final Widget child;
  _PinnedSearchBarDelegate({required this.child});

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = shrinkOffset > 0 || overlapsContent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: pinned ? AppColors.surface : Colors.transparent,
        border: pinned
            ? const Border(
                bottom: BorderSide(color: AppColors.borderSoft, width: 0.5),
              )
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

class _ShopClosedBanner extends StatelessWidget {
  final String message;
  const _ShopClosedBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF2F2),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFB91C1C),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Shop closed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7F1D1D),
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (message.trim().isNotEmpty)
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartFab extends StatelessWidget {
  final CartProvider cart;
  const _CartFab({required this.cart});

  @override
  Widget build(BuildContext context) {
    final visible = cart.totalItems > 0;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Material(
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
                    padding: const EdgeInsets.fromLTRB(10, 8, AppSpacing.md, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 18,
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
                                      horizontal: 5, vertical: 1),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandOrange,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.full),
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
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${cart.totalItems} ${cart.totalItems == 1 ? "item" : "items"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '₹${(cart.subtotalCents / 100).toStringAsFixed(0)}',
                                key: ValueKey(cart.subtotalCents),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          height: 28,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Text(
                          'Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailTheme {
  final String emoji;
  final SectionTint tint;
  const _RailTheme({required this.emoji, required this.tint});
}

class _CatChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: selected ? 1.05 : 1.0,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: EdgeInsets.fromLTRB(
                icon != null ? AppSpacing.sm : AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandBlue
                    : AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: selected ? AppColors.brandBlue : AppColors.borderSoft,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.brandBlue.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : AppShadow.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : AppColors.pageBg,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(icon!, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: selected ? 0.2 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner();

  ({String emoji, String title, String subtitle, Color tint})? _spec() {
    final day = DateTime.now().weekday;
    if (day == DateTime.saturday || day == DateTime.sunday) {
      return (
        emoji: '🎉',
        title: 'Weekend specials',
        subtitle: 'Party snacks, sweets & cold drinks',
        tint: AppColors.brandOrange,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = _spec();
    if (s == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              s.tint.withValues(alpha: 0.14),
              s.tint.withValues(alpha: 0.04),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: s.tint.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.tint,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(s.emoji, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: s.tint,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    s.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

class _DeliveryHeader extends StatelessWidget {
  const _DeliveryHeader();

  @override
  Widget build(BuildContext context) {
    if (context.watch<ShopStatusProvider>().isClosed) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery in',
              style: TextStyle(
                color: AppColors.inkFaint,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '15 minutes',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt,
                          size: 13, color: AppColors.brandBlue),
                      SizedBox(width: 2),
                      Text(
                        'Express',
                        style: TextStyle(
                          color: AppColors.brandBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.inkMuted),
                SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Delivering to your doorstep',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyView({
    this.icon = Icons.search_off,
    this.title = 'Nothing here',
    this.message = '',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(actionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(color: AppColors.brandBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _CampaignOverlay extends StatelessWidget {
  const _CampaignOverlay({
    required this.campaign,
    required this.onCategoryTap,
    required this.onClose,
  });

  final Campaign campaign;
  final void Function(int categoryId) onCategoryTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Image.network(
                      campaign.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.black,
                          width: 300,
                          height: 380,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  if (campaign.categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final cat in campaign.categories)
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => onCategoryTap(cat.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.brandBlue,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
