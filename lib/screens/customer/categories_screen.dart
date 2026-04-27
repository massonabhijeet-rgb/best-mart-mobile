import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../theme/tokens.dart';

/// Browse-by-category surface. Categories with children are rendered
/// as a section header followed by their children as tiles, matching
/// the parent/child hierarchy admins set up in the dashboard. Tap any
/// tile and the shell switches to the Home tab with that filter
/// applied.
class CategoriesScreen extends StatelessWidget {
  final void Function(int categoryId) onCategoryTap;
  const CategoriesScreen({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final all = home.categories;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            fontSize: 18,
          ),
        ),
      ),
      body: all.isEmpty
          ? const _LoadingOrEmpty()
          : _buildBody(all),
    );
  }

  Widget _buildBody(List<Category> all) {
    // Render every top-level category (parentId == null) as a tile in a
    // single 4-col grid. Tapping a tile pushes the browser screen — if
    // the category has children they'll show as the sidebar, otherwise
    // the browser just renders the product grid for that category.
    //
    // Sub-categories used to be rendered here as tiles (under their
    // parent's name as a section header); that meant parent categories
    // like "Baby Care" were invisible — only its children "Diapers &
    // Wipes" and "Feeding Essentials" appeared. The Blinkit-style flow
    // surfaces the parent as the entry point and reveals children only
    // after the user opts in to that department.
    final tops = all.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (tops.isEmpty) return const _LoadingOrEmpty();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: tops.length,
      itemBuilder: (_, i) =>
          _CategoryTile(cat: tops[i], onTap: () => onCategoryTap(tops[i].id)),
    );
  }
}

class _LoadingOrEmpty extends StatelessWidget {
  const _LoadingOrEmpty();
  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    if (home.state == LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No categories yet.',
          style: TextStyle(color: AppColors.inkFaint, fontSize: 14),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category cat;
  final VoidCallback onTap;
  const _CategoryTile({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.sectionSky,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.borderSoft,
                width: 0.6,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CachedNetworkImage(
                        imageUrl: cat.imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: 220,
                        memCacheHeight: 220,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.shopping_basket_outlined,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.shopping_basket_outlined,
                        color: AppColors.inkFaint,
                        size: 30,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cat.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
