import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

class CategoryTilesGrid extends StatelessWidget {
  final List<Category> categories;
  final void Function(int id) onTap;

  const CategoryTilesGrid({
    super.key,
    required this.categories,
    required this.onTap,
  });

  static String _emojiFor(String name) {
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
    if (n.contains('frozen') || n.contains('ice')) return '🧊';
    if (n.contains('rice') || n.contains('atta') || n.contains('flour') ||
        n.contains('grain')) {
      return '🌾';
    }
    if (n.contains('oil') || n.contains('ghee')) return '🫙';
    if (n.contains('tea') || n.contains('coffee')) return '☕';
    if (n.contains('baby')) return '🍼';
    if (n.contains('pet')) return '🐶';
    if (n.contains('clean') || n.contains('home')) return '🧼';
    if (n.contains('care') || n.contains('beauty')) return '🧴';
    return '🛒';
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop by category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap a tile to browse the shelf',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.82,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final c = categories[i];
              return _Tile(
                category: c,
                emoji: _emojiFor(c.name),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(c.id);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Category category;
  final String emoji;
  final VoidCallback onTap;

  const _Tile({
    required this.category,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadow.soft,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: AppRadius.brSm,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: category.imageUrl != null &&
                          category.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
