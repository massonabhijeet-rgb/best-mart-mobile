import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../../theme/tokens.dart';

/// Editorial seasonal landing page — rendered when the customer taps a
/// themed-page chip in the storefront's top icon row. Shows a hero
/// banner + tile grid; tile taps pop back to the storefront with the
/// matching filter (category id or search query) applied.
class ThemedPageScreen extends StatelessWidget {
  final ThemedPage page;
  const ThemedPageScreen({super.key, required this.page});

  /// Returns either a route push (push a search/category filter) or
  /// nothing if the tile's link target is invalid. Pops the themed
  /// page itself first so the navigator stack ends at the storefront.
  void _onTileTap(BuildContext context, ThemedPageTile tile) {
    final home = context.read<HomeProvider>();
    switch (tile.linkType) {
      case ThemedPageTileLinkType.category:
        if (tile.linkCategoryId != null) {
          home.setCategory(tile.linkCategoryId!);
          Navigator.of(context).pop();
        }
        break;
      case ThemedPageTileLinkType.search:
        final q = (tile.linkSearchQuery ?? '').trim();
        if (q.isNotEmpty) {
          home.setSearch(q);
          Navigator.of(context).pop();
        }
        break;
      case ThemedPageTileLinkType.productIds:
        // No dedicated "list of N specific products" surface yet; the
        // storefront's filter primitives only model category/search/
        // brand. Falling back to a snackbar is honest — better than
        // silently doing nothing or pretending we navigated.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tile "${tile.label}" — coming soon'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case ThemedPageTileLinkType.unknown:
        break;
    }
  }

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final s = hex.trim().replaceAll('#', '');
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _parseHex(page.themeColor) ?? AppColors.pageBg;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        title: Text(
          page.title,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.heroImageUrl != null && page.heroImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Image.network(
                      page.heroImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.inkFaint),
                      ),
                    ),
                  ),
                ),
              if ((page.subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  page.subtitle!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (page.tiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No tiles yet — check back soon.',
                      style: TextStyle(color: AppColors.inkFaint),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 2-column grid by default, 3-column on wider tablets.
                    final crossCount = constraints.maxWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: page.tiles.length,
                      itemBuilder: (_, i) => _TileCard(
                        tile: page.tiles[i],
                        onTap: () => _onTileTap(context, page.tiles[i]),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  final ThemedPageTile tile;
  final VoidCallback onTap;
  const _TileCard({required this.tile, required this.onTap});

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final s = hex.trim().replaceAll('#', '');
    if (s.length != 6) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _parseHex(tile.bgColor) ?? AppColors.sectionSky;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if ((tile.sublabel ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tile.sublabel!.trim(),
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: tile.imageUrl != null && tile.imageUrl!.isNotEmpty
                      ? Image.network(
                          tile.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
