import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/customer/cart_provider.dart';
import '../services/api.dart';
import '../theme/tokens.dart';

class QuickViewSheet extends StatefulWidget {
  final Product anchor;
  const QuickViewSheet({super.key, required this.anchor});

  static Future<void> show(BuildContext context, Product anchor) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickViewSheet(anchor: anchor),
    );
  }

  @override
  State<QuickViewSheet> createState() => _QuickViewSheetState();
}

class _QuickViewSheetState extends State<QuickViewSheet> {
  bool _loading = true;
  List<Product> _variants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await ApiService.getProductVariants(widget.anchor.uniqueId);
      if (!mounted) return;
      setState(() {
        _variants = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Product> get _all {
    final seen = <String>{};
    final list = <Product>[];
    for (final p in [widget.anchor, ..._variants]) {
      if (seen.add(p.uniqueId)) list.add(p);
    }
    list.sort((a, b) {
      final ua = _unitPriceCentsPerBase(a);
      final ub = _unitPriceCentsPerBase(b);
      if (ua != null && ub != null && ua.unit == ub.unit) {
        return ua.centsPer.compareTo(ub.centsPer);
      }
      if (ua != null && ub == null) return -1;
      if (ua == null && ub != null) return 1;
      return a.priceCents.compareTo(b.priceCents);
    });
    return list;
  }

  String? get _bestUniqueId {
    final ranked = _all
        .map((p) => _Ranked(p, _unitPriceCentsPerBase(p)))
        .where((r) => r.u != null)
        .toList();
    if (ranked.length < 2) return null;
    return ranked.first.p.uniqueId;
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final best = _bestUniqueId;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.anchor.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _loading
                            ? 'Loading other sizes…'
                            : (_variants.isEmpty
                                ? 'No other sizes for this product'
                                : 'Other sizes & packs'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkFaint,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.ink),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: all.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final p = all[i];
                      return _VariantRow(
                        product: p,
                        isAnchor: p.uniqueId == widget.anchor.uniqueId,
                        isBest: best != null && p.uniqueId == best,
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _Ranked {
  final Product p;
  final _UnitPrice? u;
  _Ranked(this.p, this.u);
}

class _UnitPrice {
  final double centsPer;
  final String unit;
  _UnitPrice(this.centsPer, this.unit);
}

_UnitPrice? _unitPriceCentsPerBase(Product p) {
  final label = p.unitLabel.toLowerCase();
  final match = RegExp(r'([\d]+(?:\.\d+)?)\s*(kg|g|l|ml|lb|oz)\b').firstMatch(label);
  if (match == null) return null;
  final qty = double.tryParse(match.group(1)!);
  if (qty == null || qty <= 0) return null;
  final unit = match.group(2)!;
  double base;
  String baseUnit;
  switch (unit) {
    case 'kg':
      base = qty * 1000;
      baseUnit = 'g';
      break;
    case 'g':
      base = qty;
      baseUnit = 'g';
      break;
    case 'l':
      base = qty * 1000;
      baseUnit = 'ml';
      break;
    case 'ml':
      base = qty;
      baseUnit = 'ml';
      break;
    default:
      return null;
  }
  return _UnitPrice(p.priceCents / base, baseUnit);
}

String? _formatUnitPrice(Product p) {
  final u = _unitPriceCentsPerBase(p);
  if (u == null) return null;
  final perHundred = u.centsPer * 100;
  return '₹${(perHundred / 100).toStringAsFixed(2)}/100${u.unit}';
}

class _VariantRow extends StatelessWidget {
  final Product product;
  final bool isAnchor;
  final bool isBest;
  const _VariantRow({
    required this.product,
    required this.isAnchor,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantity(product.uniqueId);
    final unitPrice = _formatUnitPrice(product);
    final outOfStock = product.stockQuantity <= 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isAnchor ? AppColors.brandGreen.withValues(alpha: 0.06) : AppColors.surface,
        border: Border.all(
          color: isAnchor ? AppColors.brandGreen : AppColors.borderSoft,
          width: isAnchor ? 1.6 : 1,
        ),
        borderRadius: AppRadius.brMd,
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
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.sectionSky,
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.brandBlue,
                          size: 22,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.sectionSky,
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        color: AppColors.brandBlue,
                        size: 22,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.unitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BEST VALUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (isAnchor) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'VIEWING',
                        style: TextStyle(
                          color: AppColors.brandGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(product.priceCents / 100).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    if (unitPrice != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· $unitPrice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 32,
            child: outOfStock
                ? Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Text(
                      'Sold out',
                      style: TextStyle(
                        color: AppColors.inkFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : qty == 0
                    ? InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          cart.add(product);
                        },
                        borderRadius: AppRadius.brSm,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.brandBlue,
                            borderRadius: AppRadius.brSm,
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                cart.remove(product.uniqueId);
                              },
                              borderRadius: AppRadius.brSm,
                              child: const SizedBox(
                                width: 28,
                                height: 32,
                                child: Icon(Icons.remove,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                            SizedBox(
                              width: 22,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: qty >= product.stockQuantity
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      cart.add(product);
                                    },
                              borderRadius: AppRadius.brSm,
                              child: SizedBox(
                                width: 28,
                                height: 32,
                                child: Icon(
                                  Icons.add,
                                  color: qty >= product.stockQuantity
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
