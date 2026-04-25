import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../theme/tokens.dart';
import 'cart_provider.dart';

/// Drill-down from an Order-Again category tile: shows every product
/// the user has previously ordered inside that category, with a quick
/// add-to-cart stepper on each row.
class OrderAgainCategoryScreen extends StatelessWidget {
  final String categoryName;
  final List<Product> products;
  const OrderAgainCategoryScreen({
    super.key,
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        title: Text(
          categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: products.length,
        itemBuilder: (_, i) => _ProductRow(product: products[i]),
      ),
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
                      placeholder: (_, __) =>
                          const ColoredBox(color: AppColors.surfaceSoft),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.inkFaint,
                          size: 24,
                        ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    icon: const Icon(Icons.add,
                        color: Colors.white, size: 16),
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
