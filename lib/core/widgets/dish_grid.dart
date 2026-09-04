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
    this.maxItems,
    this.animate = true,
  });

  final List<Dish> dishes;
  final AppStrings strings;
  final void Function(Dish) onToggleFavorite;

  /// Caps how many cards this grid lays out. A home shelf is a taste of a
  /// category, not the whole of it — the header row next to it already leads
  /// to the full list — and a shrink-wrapped grid has no laziness of its own,
  /// so every card it is handed is built immediately.
  final int? maxItems;

  /// Plays the fade/slide/scale entrance on every card in this grid.
  ///
  /// The three chained effects run to ~1.2s per card. That's fine for a
  /// screenful appearing once; it is not fine for a shelf that gets rebuilt
  /// every time it scrolls back into range, which is what a fast flick
  /// through the home feed did constantly — dozens of cards restarting a
  /// second-long animation several times a second was the stutter. Callers
  /// that rebuild this grid on every scroll pass `false` here.
  final bool animate;

  /// Beyond this the entrance stagger stops growing. It exists to make a
  /// screenful arrive in sequence; at 45 ms a step, card 40 would otherwise
  /// wait almost two seconds before fading in.
  static const _staggerLimit = 8;

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

    // A home shelf hands this a fixed, tiny slice of the menu (`maxItems`)
    // that never scrolls on its own. `GridView(shrinkWrap: true)` still
    // stands up its own nested Scrollable — a ScrollPosition, a Viewport
    // render object, gesture arenas — just to lay six cards out; building
    // and tearing that down every time a shelf scrolled back into the
    // sliver list's range was the second-long freeze on a fast flick
    // through the feed. A plain Row/Column pair needs none of that
    // machinery, so this path skips GridView entirely.
    if (maxItems != null) {
      final visible = dishes.length <= maxItems! ? dishes : dishes.sublist(0, maxItems!);
      final rows = <Widget>[];
      for (var i = 0; i < visible.length; i += 2) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < visible.length ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AspectRatio(aspectRatio: aspectRatio, child: _buildCard(context, visible[i], i))),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < visible.length
                      ? AspectRatio(aspectRatio: aspectRatio, child: _buildCard(context, visible[i + 1], i + 1))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: rows),
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
      itemBuilder: (context, index) => _buildCard(context, dishes[index], index),
    );
  }

  Widget _buildCard(BuildContext context, Dish dish, int index) {
    final card = DishCard(
      dish: dish,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
      ),
      onToggleFavorite: () => onToggleFavorite(dish),
    );
    if (!animate) return card;
    // Keyed on the dish, so the stagger replays when the list itself
    // changes — switching category on home re-deals the grid rather
    // than swapping the contents in place.
    return card
        .animate(
          key: ValueKey(dish.id),
          delay: (45 * (index < _staggerLimit ? index : _staggerLimit)).ms,
        )
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.18, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.94, end: 1, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}
