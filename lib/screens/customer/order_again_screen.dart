import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
import 'order_again_category_screen.dart';

/// Tile-grid landing showing the categories the user has previously
/// ordered from. Top categories (by previously-bought-count) surface
/// under "Frequently bought"; the rest fall into "More that you
/// ordered". Tapping a tile drills into a per-category list.
class OrderAgainScreen extends StatefulWidget {
  const OrderAgainScreen({super.key});

  @override
  State<OrderAgainScreen> createState() => _OrderAgainScreenState();
}

class _OrderAgainScreenState extends State<OrderAgainScreen> {
  bool _loading = true;
  String? _error;
  // categoryName → unique products bought, ordered newest-first.
  Map<String, List<Product>> _byCategory = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getMyOrders(),
        ApiService.getProductsPage(page: 1, pageSize: 200),
      ]);
      final orders = results[0] as List<Order>;
      final catalog = (results[1] as ProductPage).products;
      final byId = {for (final p in catalog) p.id: p};

      orders.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      final seen = <int>{};
      final groups = <String, List<Product>>{};
      for (final o in orders) {
        for (final item in o.items) {
          final pid = item.productId;
          if (pid == null) continue;
          if (seen.contains(pid)) continue;
          final product = byId[pid];
          if (product == null) continue;
          seen.add(pid);
          final cat = (product.categoryName?.trim().isNotEmpty == true)
              ? product.categoryName!
              : 'Other';
          groups.putIfAbsent(cat, () => []).add(product);
        }
      }
      if (!mounted) return;
      setState(() {
        _byCategory = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load past orders';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Order Again',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Empty(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load orders',
        body: _error!,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (_byCategory.isEmpty) {
      return const _Empty(
        icon: Icons.shopping_basket_outlined,
        title: 'Nothing to re-order yet',
        body: "Your previously bought items will show up here once you've placed an order.",
      );
    }

    // Sort categories by how many distinct products the user has bought
    // from each — most-bought floats up under "Frequently bought".
    final entries = _byCategory.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    const topN = 5;
    final top = entries.take(topN).toList();
    final rest = entries.skip(topN).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (top.isNotEmpty)
          _Section(title: 'Frequently bought', entries: top),
        if (rest.isNotEmpty)
          _Section(title: 'More that you ordered', entries: rest),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<MapEntry<String, List<Product>>> entries;
  const _Section({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (_, i) => _CategoryTile(
              category: entries[i].key,
              products: entries[i].value,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String category;
  final List<Product> products;
  const _CategoryTile({required this.category, required this.products});

  @override
  Widget build(BuildContext context) {
    final visible = products.take(2).toList();
    final more = products.length - visible.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderAgainCategoryScreen(
              categoryName: category,
              products: products,
            ),
          ));
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.sectionSky,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MiniProduct(product: visible[0])),
                        const SizedBox(width: 6),
                        Expanded(
                          child: visible.length > 1
                              ? _MiniProduct(product: visible[1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (more > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '+$more more',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.2,
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

class _MiniProduct extends StatelessWidget {
  final Product product;
  const _MiniProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.contain,
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.inkFaint,
                ),
              )
            : const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.inkFaint,
                  size: 24,
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: AppColors.inkFaint),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkFaint,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 12),
          Center(child: action!),
        ],
      ],
    );
  }
}
