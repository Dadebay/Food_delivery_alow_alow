import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/dish_grid.dart';
import '../catalog/catalog_provider.dart';
import '../home/dish_detail_screen.dart';
import '../home/widgets/dish_card.dart';

/// Favorites tab — every dish the customer has hearted, same card as the
/// home grid.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CatalogProvider>().syncFavorites(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final catalog = context.watch<CatalogProvider>();
    final favorites = catalog.favorites;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(s.favoritesTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/empty_fav.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.fitHeight,
                    ),
                    const SizedBox(height: 16),
                    Text(s.favoritesEmpty, style: AppText.h2),
                    const SizedBox(height: 8),
                    Text(
                      s.favoritesEmptyHint,
                      textAlign: TextAlign.center,
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: favorites.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: DishGrid.aspectRatio,
              ),
              itemBuilder: (context, index) {
                final dish = favorites[index];
                return DishCard(
                  dish: dish,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DishDetailScreen(dish: dish),
                    ),
                  ),
                  onToggleFavorite: () => catalog.toggleFavorite(dish),
                );
              },
            ),
    );
  }
}
