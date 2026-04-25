import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme/tokens.dart';
import 'cart_provider.dart';

/// Lists every product the user has ordered before, grouped by
/// category. Each tile is a quick-add tap so they can re-stock without
/// scrolling the full storefront.
class OrderAgainScreen extends StatefulWidget {
  const OrderAgainScreen({super.key});

  @override
  State<OrderAgainScreen> createState() => _OrderAgainScreenState();
}

class _OrderAgainScreenState extends State<OrderAgainScreen> {
  bool _loading = true;
  String? _error;
  // Products the user has bought, deduped by productId, ordered newest-first.
  List<Product> _products = [];

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
        // Fetch enough catalog to resolve most past purchases. 200 is
        // generous for a small grocery catalog; large catalogs can
        // page later.
        ApiService.getProductsPage(page: 1, pageSize: 200),
      ]);
      final orders = results[0] as List<Order>;
      final catalog = (results[1] as ProductPage).products;
      final byId = {for (final p in catalog) p.id: p};

      // Walk orders newest → oldest, dedupe items by productId.
      orders.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      final seen = <int>{};
      final out = <Product>[];
      for (final o in orders) {
        for (final item in o.items) {
          final pid = item.productId;
          if (pid == null) continue;
          if (seen.contains(pid)) continue;
          final product = byId[pid];
          if (product == null) continue; // archived / out of catalog
          seen.add(pid);
          out.add(product);
        }
      }
      if (!mounted) return;
      setState(() {
        _products = out;
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
        action: TextButton(
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }
    if (_products.isEmpty) {
      return const _Empty(
        icon: Icons.shopping_basket_outlined,
        title: 'Nothing to re-order yet',
        body: "Your previously bought items will show up here once you've placed an order.",
      );
    }

    // Group by category name (falls back to "Other" for un-categorised).
    final groups = <String, List<Product>>{};
    for (final p in _products) {
      final cat = (p.categoryName?.trim().isNotEmpty == true)
          ? p.categoryName!
          : 'Other';
      groups.putIfAbsent(cat, () => []).add(p);
    }
    final orderedKeys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: orderedKeys.length,
      itemBuilder: (_, idx) {
        final cat = orderedKeys[idx];
        final list = groups[cat]!;
        return _CategorySection(category: cat, products: list);
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Product> products;
  const _CategorySection({required this.category, required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${products.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final p in products) _ProductRow(product: p),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantity(product.uniqueId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: SizedBox(
              width: 56,
              height: 56,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 180,
                      memCacheHeight: 180,
                      placeholder: (_, __) => const ColoredBox(
                        color: AppColors.surfaceSoft,
                      ),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppColors.inkFaint, size: 24),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceSoft,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.inkFaint,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.unitLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${(product.priceCents / 100).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (qty == 0)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandBlue,
                side: const BorderSide(color: AppColors.brandBlue, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => cart.add(product),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => cart.remove(product.uniqueId),
                    icon: const Icon(Icons.remove,
                        color: Colors.white, size: 16),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => cart.add(product),
                    icon:
                        const Icon(Icons.add, color: Colors.white, size: 16),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
        ],
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
