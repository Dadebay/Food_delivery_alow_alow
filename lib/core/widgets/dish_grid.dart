import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../modules/home/dish_detail_screen.dart';
import '../../modules/home/widgets/dish_card.dart';
import 'responsive.dart';
import '../localization/app_strings.dart';
import '../models/dish.dart';
import '../theme/app_text_styles.dart';

/// The two-column dish grid — used on the home tab and the category dishes
/// screen, so both read from one place instead of drifting apart. Favorites
/// already reaches into the home module for the same two widgets, so this
/// follows that existing pattern rather than inventing a new one.
class DishGrid extends StatefulWidget {
  const DishGrid({
    super.key,
    required this.dishes,
    required this.strings,
    required this.onToggleFavorite,
    this.maxItems,
    this.animate = true,
    this.scrollable = false,
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

  /// Whether this grid owns its own scrolling.
  ///
  /// False by default because the usual caller — the home feed — already has
  /// a scroll view around it, and a nested one would fight it. A screen that
  /// hands this grid the whole body has no such view, and without this the
  /// cards simply run off the bottom with nothing to drag: shrink-wrapped
  /// content that refuses to scroll. Scrolling here also restores the lazy
  /// building a shrink-wrapped grid gives up.
  final bool scrollable;

  /// Beyond this the entrance stagger stops growing. It exists to make a
  /// screenful arrive in sequence; at 45 ms a step, card 40 would otherwise
  /// wait almost two seconds before fading in.
  static const _staggerLimit = 8;

  /// Room for the photo plus the white block under it — a two-line name and
  /// the price/quick-add row — with slack left over for larger text
  /// settings, which the card's own Spacer absorbs.
  static const aspectRatio = 0.80;

  @override
  State<DishGrid> createState() => _DishGridState();
}

class _DishGridState extends State<DishGrid> {
  /// Entrance animations belong to the screenful that is on screen when the
  /// grid opens. A lazy grid builds a card the moment it scrolls into range,
  /// so without a cut-off every card flicked past starts a ~800 ms
  /// fade/slide/scale of its own — on a fast scroll the user outruns it and
  /// sees half-faded cards sliding into place, or blank space where a card
  /// should already be. Past this deadline cards simply appear.
  late final DateTime _entranceDeadline = DateTime.now().add(
    const Duration(milliseconds: 700),
  );

  bool get _withinEntrance => DateTime.now().isBefore(_entranceDeadline);

  @override
  Widget build(BuildContext context) {
    if (widget.dishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text(widget.strings.noResults, style: AppText.bodyMuted)),
      );
    }

    // A home shelf hands this a fixed, tiny slice of the menu (`widget.maxItems`)
    // that never scrolls on its own. `GridView(shrinkWrap: true)` still
    // stands up its own nested Scrollable — a ScrollPosition, a Viewport
    // render object, gesture arenas — just to lay six cards out; building
    // and tearing that down every time a shelf scrolled back into the
    // sliver list's range was the second-long freeze on a fast flick
    // through the feed. A plain Row/Column pair needs none of that
    // machinery, so this path skips GridView entirely.
    if (widget.maxItems != null) {
      final visible = widget.dishes.length <= widget.maxItems! ? widget.dishes : widget.dishes.sublist(0, widget.maxItems!);
      // The shelf was hard-wired to two cards a row, so a tablet got the same
      // pair blown up to half the screen each while the grid pages beside it
      // had already moved to three.
      final columns = Responsive.gridColumns(context);
      final rows = <Widget>[];
      for (var i = 0; i < visible.length; i += columns) {
        final cells = <Widget>[];
        for (var column = 0; column < columns; column++) {
          if (column > 0) cells.add(const SizedBox(width: 14));
          final index = i + column;
          cells.add(
            Expanded(
              child: index < visible.length
                  // The empty trailing cell keeps the last row's cards the
                  // same width as every row above it.
                  ? AspectRatio(
                      aspectRatio: DishGrid.aspectRatio,
                      child: _buildCard(context, visible[index], index),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: i + columns < visible.length ? 14 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cells,
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
      shrinkWrap: !widget.scrollable,
      // The page already supplies its horizontal gutter. Keeping a second
      // inset here made product cards unnecessarily narrow on phones.
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: widget.scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.dishes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: DishGrid.aspectRatio,
      ),
      itemBuilder: (context, index) => _buildCard(context, widget.dishes[index], index),
    );
  }

  Widget _buildCard(BuildContext context, Dish dish, int index) {
    final card = DishCard(
      dish: dish,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DishDetailScreen(dish: dish)),
      ),
      onToggleFavorite: () => widget.onToggleFavorite(dish),
    );
    if (!widget.animate || !_withinEntrance) return card;
    // Keyed on the dish, so the stagger replays when the list itself
    // changes — switching category on home re-deals the grid rather
    // than swapping the contents in place.
    return card
        .animate(
          key: ValueKey(dish.id),
          delay: (45 * (index < DishGrid._staggerLimit ? index : DishGrid._staggerLimit)).ms,
        )
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.18, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.94, end: 1, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}
