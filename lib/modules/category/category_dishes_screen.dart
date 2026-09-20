import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/dish_grid.dart';
import '../catalog/catalog_provider.dart';

/// Dishes in one category — pushed from a category card. Same grid as home,
/// just pre-filtered and given its own back-button screen instead of a chip.
class CategoryDishesScreen extends StatelessWidget {
  const CategoryDishesScreen({super.key, required this.categoryId, required this.categoryName});

  final String categoryId;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final catalog = context.watch<CatalogProvider>();
    final dishes = catalog.forCategory(categoryId);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(categoryName),

        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/app_food_background.png', fit: BoxFit.cover)),
          Padding(
            // Extra room up top so the first row of cards is not glued to the
            // app bar — the grid's own inset alone reads as a crop.
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: DishGrid(
              dishes: dishes,
              strings: s,
              onToggleFavorite: catalog.toggleFavorite,
              // This grid *is* the page — nothing above it scrolls, so it has
              // to do it itself.
              scrollable: true,
            ),
          ),
        ],
      ),
    );
  }
}
