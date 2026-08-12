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
  const CategoryDishesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

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
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DishGrid(
          dishes: dishes,
          strings: s,
          onToggleFavorite: catalog.toggleFavorite,
        ),
      ),
    );
  }
}
