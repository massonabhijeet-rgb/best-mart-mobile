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
    // Split top-level vs children. A "top-level" is anything with
    // parentId == null. Anything else is a sub-category.
    final byParent = <int, List<Category>>{};
    final tops = <Category>[];
    for (final c in all) {
      if (c.parentId == null) {
        tops.add(c);
      } else {
        byParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }
    tops.sort((a, b) => a.name.compareTo(b.name));

    // Tops with children get a header + sub-grid; tops without
    // children render as their own tile in a "More" section so the
    // user can still discover/filter on them.
    final sections = <Widget>[];
    final loners = <Category>[];
    for (final top in tops) {
      final children = (byParent[top.id] ?? []);
      if (children.isEmpty) {
        loners.add(top);
        continue;
      }
      children.sort((a, b) => a.name.compareTo(b.name));
      sections.add(_Section(
        title: top.name,
        items: children,
        onTap: onCategoryTap,
      ));
    }
    if (loners.isNotEmpty) {
      sections.add(_Section(
        title: 'More',
        items: loners,
        onTap: onCategoryTap,
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: sections,
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

class _Section extends StatelessWidget {
  final String title;
  final List<Category> items;
  final void Function(int) onTap;
  const _Section({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _CategoryTile(cat: items[i], onTap: () => onTap(items[i].id)),
          ),
        ),
      ],
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
