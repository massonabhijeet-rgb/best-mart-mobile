import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../providers/shop_status_provider.dart';
import '../../services/api.dart';
import '../../services/auth_provider.dart';
import 'address_picker_screen.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_strip.dart';
import '../../widgets/category_tiles_grid.dart';
import '../../widgets/home_rail.dart';
import '../../widgets/product_card.dart';
import '../../widgets/section_background.dart';
import '../../widgets/skeleton.dart';
import 'profile_screen.dart';
import 'themed_page_screen.dart';

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});
  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;
  Timer? _hintRotator;
  int _hintIndex = 0;
  Timer? _searchLogger;
  // Recent search chips. Loaded once on first focus + after each clear.
  List<String> _searchHistory = const [];
  bool _historyLoaded = false;
  // Type-ahead suggestions while the user types. Fetched off the same
  // /products/page endpoint with pageSize=8 — we just surface the names.
  List<Product> _suggestions = const [];
  String _suggestionFor = '';
  Timer? _suggestionDebounce;

  // "More from <category>" cache. Keyed by `<search>|<categoryId>` so we
  // re-fetch when either changes, but never thrash on every grid scroll.
  String? _relatedSig;
  bool _loadingRelated = false;
  String? _relatedCategoryName;
  List<Product> _relatedProducts = const [];

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
    _searchFocus.addListener(_onSearchFocusChanged);
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
    _searchLogger?.cancel();
    _suggestionDebounce?.cancel();
    _hintRotator?.cancel();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus && !_historyLoaded) {
      _historyLoaded = true;
      ApiService.getSearchHistory().then((list) {
        if (!mounted) return;
        setState(() => _searchHistory = list);
      });
    }
    // Trigger a rebuild so the empty-search overlay opens/closes with focus.
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    setState(() => _searchHistory = const []);
    await ApiService.clearSearchHistory();
  }

  void _useHistoryQuery(String query) {
    _searchCtrl.text = query;
    _searchCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _searchFocus.unfocus();
    context.read<HomeProvider>().setSearch(query);
    // Bump it back to the top of history.
    ApiService.logSearch(query);
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
    final trimmed = value.trim();
    // Rebuild every keystroke so the placeholder overlay and the
    // mic/close suffix icon swap update immediately. Without this the
    // surrounding Stack only rebuilds once the suggestion debounce
    // fires (~180ms later), leaving the hint visible behind the
    // typed text.
    setState(() {});
    // Type-ahead suggestions on a tighter 180ms debounce — they're a
    // peek, so latency matters more than the heavier full-grid query
    // 120ms behind it.
    _suggestionDebounce?.cancel();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
    } else {
      _suggestionDebounce = Timer(const Duration(milliseconds: 180), () async {
        if (!mounted) return;
        if (trimmed == _suggestionFor) return;
        _suggestionFor = trimmed;
        try {
          final page = await ApiService.getProductsPage(
            page: 1,
            pageSize: 8,
            search: trimmed,
          );
          if (!mounted || _searchCtrl.text.trim() != trimmed) return;
          setState(() => _suggestions = page.products);
        } catch (_) {
          // suggestions are non-critical
        }
      });
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<HomeProvider>().setSearch(value.trim());
    });
    // Log queries the user actually settled on (1.2s after last keystroke
    // and ≥ 2 chars), so noisy in-progress typing doesn't pollute history.
    _searchLogger?.cancel();
    if (trimmed.length >= 2) {
      _searchLogger = Timer(const Duration(milliseconds: 1200), () {
        ApiService.logSearch(trimmed).then((_) {
          if (!mounted) return;
          // Optimistically prepend / hoist to top so the history list is
          // fresh next time the field is focused, without a refetch.
          setState(() {
            final updated = [
              trimmed,
              ..._searchHistory.where(
                (q) => q.toLowerCase() != trimmed.toLowerCase(),
              ),
            ];
            _searchHistory =
                updated.length > 10 ? updated.sublist(0, 10) : updated;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final shop = context.watch<ShopStatusProvider>();

    _maybeShowCampaignPopup(home);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      extendBodyBehindAppBar: true,
      appBar: _appBar(),
      body: Container(
        // Solid light-blue hero band (top ~30% — covers app bar, delivery
        // header, search bar, and category icon row) that transitions
        // sharply to white. Mirrors the Blinkit reference but in our
        // brand palette instead of yellow.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4E5FB),
              Color(0xFFD4E5FB),
              Color(0xFFFFFFFF),
            ],
            stops: [0, 0.34, 0.40],
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
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
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
            ClipRRect(
              borderRadius: AppRadius.brSm,
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 32,
                height: 32,
                cacheWidth: 96,
                cacheHeight: 96,
                fit: BoxFit.cover,
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
          const _ProfileAvatarButton(),
          const SizedBox(width: AppSpacing.md),
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
          if (_searchFocus.hasFocus &&
              _searchCtrl.text.trim().isEmpty &&
              _searchHistory.isNotEmpty)
            SliverToBoxAdapter(child: _recentSearches()),
          if (_searchFocus.hasFocus &&
              _searchCtrl.text.trim().isNotEmpty &&
              _suggestions.isNotEmpty)
            SliverToBoxAdapter(child: _suggestionList()),
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
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isEmpty) return;
                ApiService.logSearch(t);
                _searchFocus.unfocus();
              },
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
            // Hide the rotating placeholder the moment the field gains
            // focus — once the user has tapped in, the recent-searches
            // chip strip is the helpful prompt, not the rotating hint.
            if (_searchCtrl.text.isEmpty && !_searchFocus.hasFocus)
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

  Widget _suggestionList() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _suggestions.length; i++)
            InkWell(
              onTap: () => _useSuggestion(_suggestions[i]),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(AppRadius.md) : Radius.zero,
                bottom: i == _suggestions.length - 1
                    ? const Radius.circular(AppRadius.md)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _suggestions[i].imageUrl != null &&
                              _suggestions[i].imageUrl!.isNotEmpty
                          ? Image.network(
                              _suggestions[i].imageUrl!,
                              fit: BoxFit.contain,
                              cacheWidth: 108,
                              errorBuilder: (_, _e, _s) => const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.inkFaint,
                                size: 18,
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.inkFaint,
                              size: 18,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _suggestions[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: AppColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _useSuggestion(Product p) {
    HapticFeedback.selectionClick();
    final q = p.name;
    _searchCtrl.text = q;
    _searchCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: q.length));
    _searchFocus.unfocus();
    setState(() => _suggestions = const []);
    context.read<HomeProvider>().setSearch(q);
    ApiService.logSearch(q);
  }

  Widget _recentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 6),
                const Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear search history',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _clearHistory();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in _searchHistory)
                  InkWell(
                    onTap: () => _useHistoryQuery(q),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(HomeProvider home) {
    if (home.categories.isEmpty) return const SizedBox.shrink();
    // Show a curated set of daily-essential categories instead of the
    // full catalog. Match against keywords first; whatever's left from
    // the prioritised list comes from top-level parents (or flat) up
    // to a max of 6 so the row stays a quick-shortcut bar.
    final tops = home.categories.where((c) => c.parentId == null).toList();
    final pool = tops.isNotEmpty ? tops : home.categories;
    final dailyKeywords = [
      ['fruit', 'veg'],
      ['dairy', 'milk', 'egg'],
      ['snack', 'chip', 'namkeen'],
      ['drink', 'bever', 'juice', 'tea', 'coffee'],
      ['bread', 'bakery'],
      ['care', 'beauty', 'personal'],
    ];
    final picks = <Category>[];
    final usedIds = <int>{};
    for (final group in dailyKeywords) {
      for (final c in pool) {
        if (usedIds.contains(c.id)) continue;
        final n = c.name.toLowerCase();
        if (group.any(n.contains)) {
          picks.add(c);
          usedIds.add(c.id);
          break;
        }
      }
    }
    // Top up with whatever's left so users with off-keyword names
    // still see their categories.
    for (final c in pool) {
      if (picks.length >= 6) break;
      if (usedIds.contains(c.id)) continue;
      picks.add(c);
      usedIds.add(c.id);
    }

    // Themed-page chips ride alongside category chips in the same row,
    // sandwiched between "All" and the daily-essentials. They never look
    // "selected" (tapping them navigates instead of toggling a filter
    // on the home grid).
    final themed = home.themedPages;
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _CatIconChip(
            label: 'All',
            icon: Icons.apps_rounded,
            color: AppColors.brandBlue,
            entryIndex: 0,
            selected: home.categoryId == null,
            onTap: () => home.setCategory(null),
          ),
          for (var i = 0; i < themed.length; i++)
            _CatIconChip(
              label: themed[i].title,
              icon: Icons.auto_awesome_rounded,
              color: AppColors.brandOrange,
              imageUrl: themed[i].navIconUrl,
              entryIndex: i + 1,
              selected: false,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ThemedPageScreen(page: themed[i]),
                ));
              },
            ),
          for (var i = 0; i < picks.length; i++)
            _CatIconChip(
              label: picks[i].name,
              icon: _iconForCategory(picks[i].name).$1,
              color: _iconForCategory(picks[i].name).$2,
              // Stagger by index so the row enters with a soft cascade
              // from the right edge on every storefront mount.
              entryIndex: i + 1 + themed.length,
              selected: home.categoryId == picks[i].id,
              onTap: () => home.setCategory(
                home.categoryId == picks[i].id ? null : picks[i].id,
              ),
            ),
        ],
      ),
    );
  }

  // Icon + accent colour for the top-row category chip. Looked up by
  // category-name keyword so admins don't have to upload icons; the
  // tinted circle behind the icon picks up the same colour at low alpha.
  static (IconData, Color) _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) {
      return (Icons.eco_rounded, const Color(0xFF1A7A44));
    }
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg')) {
      return (Icons.local_drink_rounded, const Color(0xFF1976D2));
    }
    if (n.contains('bread') || n.contains('bakery')) {
      return (Icons.bakery_dining_rounded, const Color(0xFFC97A1F));
    }
    if (n.contains('meat') || n.contains('chicken') || n.contains('fish')) {
      return (Icons.set_meal_rounded, const Color(0xFFB71C1C));
    }
    if (n.contains('snack') || n.contains('chip') || n.contains('namkeen')) {
      return (Icons.cookie_rounded, const Color(0xFFE07B00));
    }
    if (n.contains('drink') || n.contains('bever') || n.contains('juice')) {
      return (Icons.local_cafe_rounded, const Color(0xFF1976D2));
    }
    if (n.contains('choco') || n.contains('sweet') || n.contains('candy')) {
      return (Icons.cake_rounded, const Color(0xFF6D4C41));
    }
    if (n.contains('personal') || n.contains('care') || n.contains('beauty')) {
      return (Icons.brush_rounded, const Color(0xFFC2185B));
    }
    if (n.contains('home') || n.contains('clean') || n.contains('house')) {
      return (Icons.cleaning_services_rounded, const Color(0xFF00838F));
    }
    if (n.contains('frozen') || n.contains('ice')) {
      return (Icons.ac_unit_rounded, const Color(0xFF03A9F4));
    }
    if (n.contains('rice') || n.contains('atta') || n.contains('flour') ||
        n.contains('grain') || n.contains('dal')) {
      return (Icons.grain_rounded, const Color(0xFF8D6E63));
    }
    if (n.contains('oil') || n.contains('ghee')) {
      return (Icons.opacity_rounded, const Color(0xFFFFA000));
    }
    if (n.contains('tea') || n.contains('coffee')) {
      return (Icons.coffee_rounded, const Color(0xFF5D4037));
    }
    if (n.contains('baby') || n.contains('kid')) {
      return (Icons.child_care_rounded, const Color(0xFFF06292));
    }
    if (n.contains('pet')) {
      return (Icons.pets_rounded, const Color(0xFF795548));
    }
    if (n.contains('summer') || n.contains('cool')) {
      return (Icons.wb_sunny_rounded, const Color(0xFFFB8C00));
    }
    if (n.contains('electronic') || n.contains('appliance')) {
      return (Icons.headphones_rounded, const Color(0xFF512DA8));
    }
    if (n.contains('pharma') || n.contains('health') || n.contains('medic')) {
      return (Icons.medication_rounded, const Color(0xFF388E3C));
    }
    return (Icons.shopping_basket_rounded, AppColors.brandBlue);
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

    // "Picked for you" — derived server-side from this user's recent
    // search queries. Placed first because it's the most personal signal
    // we have; hidden when empty so guests / users with no signal aren't
    // staring at a blank rail.
    if (rails.pickedForYou.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: HomeRail(
          title: 'Picked for you',
          subtitle: 'Based on what you searched recently',
          emoji: '✨',
          tint: SectionTint.lavender,
          products: rails.pickedForYou,
        ),
      ));
      addGap();
    }

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

  // Picks the most-common categoryId out of the search hits, then
  // (once per <search,category> pair) fetches more products from that
  // same category so the page has somewhere to go after the exact
  // matches end. Searching "coke" → shown Coca-Cola hits + Pepsi /
  // Campa / 7Up etc. under "More from Cold Drinks".
  void _maybeLoadRelatedFromSearch(HomeProvider home) {
    if (home.search.isEmpty) {
      if (_relatedProducts.isNotEmpty || _relatedSig != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _relatedProducts = const [];
            _relatedCategoryName = null;
            _relatedSig = null;
          });
        });
      }
      return;
    }
    if (!home.firstGridLoaded || home.gridProducts.isEmpty) return;
    if (_loadingRelated) return;

    final counts = <int, int>{};
    final names = <int, String>{};
    for (final p in home.gridProducts) {
      final cid = p.categoryId;
      if (cid == null) continue;
      counts[cid] = (counts[cid] ?? 0) + 1;
      if (p.categoryName != null && p.categoryName!.isNotEmpty) {
        names[cid] = p.categoryName!;
      }
    }
    if (counts.isEmpty) return;
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final catId = top.key;
    final catName = names[catId] ?? '';
    final sig = '${home.search}|$catId';
    if (_relatedSig == sig) return;

    _relatedSig = sig;
    _loadingRelated = true;
    final shownIds = home.gridProducts.map((p) => p.id).toSet();
    ApiService.getProductsPage(page: 1, pageSize: 30, categoryId: catId)
        .then((page) {
      if (!mounted) return;
      setState(() {
        _relatedCategoryName = catName;
        _relatedProducts = page.products
            .where((p) => !shownIds.contains(p.id))
            .take(20)
            .toList();
        _loadingRelated = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _loadingRelated = false);
    });
  }

  List<Widget> _buildFilteredSlivers(HomeProvider home, BuildContext context) {
    // Schedule the related-products fetch outside this build pass so we
    // don't setState during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeLoadRelatedFromSearch(home);
    });
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
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: Text(
                "You've reached the end of these matches.",
                style: TextStyle(color: AppColors.inkFaint, fontSize: 12),
              ),
            ),
          ),
        ),
      if (_relatedProducts.isNotEmpty &&
          home.search.isNotEmpty &&
          home.firstGridLoaded)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.recommend_rounded,
                    size: 18, color: AppColors.brandBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'More from ${_relatedCategoryName ?? "this category"}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_relatedProducts.isNotEmpty &&
          home.search.isNotEmpty &&
          home.firstGridLoaded)
        _productGrid(_relatedProducts),
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

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final source = (user?.fullName ?? '').trim().isNotEmpty
        ? user!.fullName!.trim()
        : (user?.email ?? '').trim();
    final initial =
        source.isNotEmpty ? source.characters.first.toUpperCase() : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.borderSoft, width: 1),
            ),
            child: initial.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: AppColors.brandBlueDark,
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.brandBlueDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1,
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

/// Icon-on-top chip used in the hero band's top-row. Slides in from
/// the right with a small per-index stagger when the storefront first
/// mounts, so the row "wakes up" instead of popping in flat.
class _CatIconChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int entryIndex;
  final bool selected;
  final VoidCallback onTap;
  /// When set, the chip renders this network image instead of the
  /// icon — used for admin-uploaded themed-page nav icons.
  final String? imageUrl;
  const _CatIconChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.entryIndex,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 60 * entryIndex);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // First (delay/total) of the timeline holds the chip offscreen
        // to fake a per-index stagger inside a single tween.
        final delayed = (t - entryIndex * 0.06).clamp(0.0, 1.0);
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(28 * (1 - delayed), 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.ink : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: imageUrl != null && imageUrl!.isNotEmpty
                      ? Clip.antiAlias
                      : Clip.none,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: color, size: 24),
                        )
                      : Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.ink,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

class _DeliveryHeader extends StatefulWidget {
  const _DeliveryHeader();

  @override
  State<_DeliveryHeader> createState() => _DeliveryHeaderState();
}

class _DeliveryHeaderState extends State<_DeliveryHeader> {
  List<SavedAddress> _addresses = [];
  SavedAddress? _picked;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (!context.read<AuthProvider>().isLoggedIn) return;
    try {
      final list = await ApiService.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        // Default to most-used so it lines up with the checkout pre-pick.
        if (list.isNotEmpty) {
          _picked = list.reduce((a, b) => a.useCount >= b.useCount ? a : b);
        }
      });
    } catch (_) {}
  }

  Future<void> _openPicker() async {
    HapticFeedback.selectionClick();
    final result = await AddressPickerScreen.open(
      context,
      savedAddresses: _addresses,
      selectedSavedAddressId: _picked?.id,
      initialLatitude: _picked?.latitude,
      initialLongitude: _picked?.longitude,
      initialAddressLine: _picked?.deliveryAddress ?? '',
      initialFullName: _picked?.fullName ?? '',
      initialPhone: _picked?.phone ?? '',
      initialNotes: _picked?.deliveryNotes ?? '',
      fetchCurrentLocationOnOpen: _picked == null,
    );
    if (!mounted || result == null) return;
    // Refresh from server in case the picker added/edited a saved
    // address. The picker resolves savedAddressId when an existing one
    // was chosen, so we re-pick by id; otherwise show the picked text.
    await _loadAddresses();
    if (!mounted) return;
    if (result.savedAddressId != null) {
      final match = _addresses.firstWhere(
        (a) => a.id == result.savedAddressId,
        orElse: () => SavedAddress(
          id: result.savedAddressId!,
          fullName: result.fullName,
          phone: result.phone,
          deliveryAddress: result.addressLine,
          deliveryNotes: result.deliveryNotes,
          latitude: result.latitude,
          longitude: result.longitude,
          useCount: 0,
        ),
      );
      setState(() => _picked = match);
    } else {
      setState(() => _picked = SavedAddress(
            id: 0,
            fullName: result.fullName,
            phone: result.phone,
            deliveryAddress: result.addressLine,
            deliveryNotes: result.deliveryNotes,
            latitude: result.latitude,
            longitude: result.longitude,
            useCount: 0,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<ShopStatusProvider>().isClosed) {
      return const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivering in',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.1,
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
                    fontSize: 32,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 14, color: AppColors.brandBlueDark),
                      SizedBox(width: 4),
                      Text(
                        'Express',
                        style: TextStyle(
                          color: AppColors.brandBlueDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openPicker,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Builder(builder: (ctx) {
                    // Prefer the saved address's name (it's the contact
                    // we'd hand to the rider), fall back to the logged-in
                    // user's profile name.
                    final picked = _picked;
                    final pickedName = picked?.fullName.trim() ?? '';
                    final authName =
                        ctx.watch<AuthProvider>().user?.fullName?.trim() ?? '';
                    final name = pickedName.isNotEmpty
                        ? pickedName
                        : authName.isNotEmpty
                            ? authName
                            : 'Set name';
                    final addressLine =
                        (picked?.deliveryAddress.trim().isNotEmpty == true)
                            ? picked!.deliveryAddress
                            : 'Tap to set delivery address';
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$name · ',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            addressLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.inkMuted,
                        ),
                      ],
                    );
                  }),
                ),
              ),
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
