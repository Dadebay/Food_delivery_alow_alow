import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../modules/home/dish_detail_screen.dart';
import '../../modules/home/widgets/dish_card.dart';
import '../localization/app_strings.dart';
import '../models/dish.dart';
import '../theme/app_text_styles.dart';

/// The two-column dish grid — used on the home tab and the category dishes
/// screen, so both read from one place instead of drifting apart. Favorites
/// already reaches into the home module for the same two widgets, so this
/// follows that existing pattern rather than inventing a new one.
class DishGrid extends StatelessWidget {
  const DishGrid({
    super.key,
    required this.dishes,
    required this.strings,
    required this.onToggleFavorite,
  });

  final List<Dish> dishes;
  final AppStrings strings;
  final void Function(Dish) onToggleFavorite;

  /// Room for the photo plus the white block under it — a two-line name and
  /// the price/quick-add row — with slack left over for larger text
  /// settings, which the card's own Spacer absorbs.
  static const aspectRatio = 0.80;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text(strings.noResults, style: AppText.bodyMuted)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      // The page already supplies its horizontal gutter. Keeping a second
      // inset here made product cards unnecessarily narrow on phones.
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dishes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        final dish = dishes[index];
        return DishCard(
              dish: dish,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
              ),
              onToggleFavorite: () => onToggleFavorite(dish),
            )
            // Keyed on the dish, so the stagger replays when the list itself
            // changes — switching category on home re-deals the grid rather
            // than swapping the contents in place.
            .animate(key: ValueKey(dish.id), delay: (45 * index).ms)
            .fadeIn(duration: 380.ms, curve: Curves.easeOut)
            .slideY(
              begin: 0.18,
              end: 0,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            )
            .scaleXY(
              begin: 0.94,
              end: 1,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}
