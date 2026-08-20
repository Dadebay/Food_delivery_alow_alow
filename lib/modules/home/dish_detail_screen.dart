import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/dish.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/cart_fly_animation.dart';
import '../../core/widgets/dish_grid.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../../core/widgets/favorite_toggle.dart';
import '../catalog/catalog_provider.dart';
import '../cart/cart_provider.dart';

/// A dish's own page — full-bleed photo, a white sheet of details riding
/// up over it, then a shelf of other dishes from the same category so
/// browsing doesn't dead-end here.
///
/// Replaces the old bottom sheet: a sheet is for a quick glance, but with a
/// related-dishes shelf underneath there's a whole page of content to
/// scroll through, and that wants a real screen with its own back button
/// and scroll position — not a sheet fighting the keyboard for height.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dish});

  final Dish dish;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  static const _photoHeight = 320.0;
  static const _sheetOverlap = 26.0;

  // Fixed at 1 — no on-page stepper; adjusting the quantity happens on the
  // grid's own quick-add stepper after the dish is in the cart.
  static const _quantity = 1;
  final TextEditingController _note = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.dishOpened(widget.dish);
  }

  @override
  void dispose() {
    _note.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dish = widget.dish;
    final catalog = context.watch<CatalogProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: _photoHeight,
                backgroundColor: AppColors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _RoundIconButton(
                    icon: AppIcons.back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FavoriteToggle(
                      active: dish.isFavorite,
                      onTap: () => catalog.toggleFavorite(dish),
                      size: 20,
                    ),
                  ),
                ],
                // Sits invisible in the collapsed toolbar row while the
                // photo is still open, and only fades in once the photo has
                // fully scrolled away — driven off actual scroll offset
                // rather than FlexibleSpaceBar's own built-in fade, which
                // shows the title too early, still over the photo.
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final collapseDistance = _photoHeight - kToolbarHeight;
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final progress = collapseDistance <= 0
                        ? 1.0
                        : (offset / collapseDistance).clamp(0.0, 1.0);
                    return Opacity(opacity: progress, child: child);
                  },
                  child: Text(
                    dish.name,
                    style: AppText.h2.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      DishThumbnail(
                        dish: dish,
                        borderRadius: BorderRadius.zero,
                      ),
                      // Just enough shade for the badge and buttons to hold
                      // up over a bright photo.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x40000000), Colors.transparent],
                            stops: [0.0, 0.32],
                          ),
                        ),
                      ),
                      if (dish.hasDiscount)
                        Positioned(
                          left: 16,
                          bottom: _sheetOverlap + 14,
                          child: _Badge(text: '-${dish.discountPercent}%'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -_sheetOverlap),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    // Extra top padding, beyond just the sheet's own
                    // overlap into the photo — otherwise the name sits
                    // right at the rounded edge, crowding the photo.
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.name,
                          style: AppText.h2.copyWith(fontSize: 25),
                        ),
                        if (_meta(dish, s).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_meta(dish, s), style: AppText.bodyMuted),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              Fmt.money(dish.discountedPrice),
                              style: AppText.figure.copyWith(fontSize: 22),
                            ),
                            if (dish.hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                Fmt.money(dish.price),
                                style: AppText.bodyMuted.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (dish.description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(dish.description, style: AppText.bodyMuted),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(
                child: _RelatedDishes(
                  dish: dish,
                  catalog: catalog,
                  title: s.moreFromCategory,
                ),
              ),
              // Clears the floating "add to cart" bar, which has no
              // background of its own to reserve this space by itself.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AddToCartBar(dish: dish, quantity: _quantity, note: _note),
          ),
        ],
      ),
    );
  }

  String _meta(Dish dish, AppStrings s) {
    final parts = <String>[];
    if (dish.portionLabel != null) parts.add(dish.portionLabel!);
    if (dish.prepMinutes != null) parts.add(s.minutesShort(dish.prepMinutes!));
    return parts.join(' · ');
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.dish,
    required this.quantity,
    required this.note,
  });

  final Dish dish;
  final int quantity;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: AppButton(
          label:
              '${s.addToCart} · ${Fmt.money(dish.discountedPrice * quantity)}',
          onPressed: () {
            context.read<CartProvider>().add(
              dish,
              quantity: quantity,
              note: note.text.trim().isEmpty ? null : note.text.trim(),
            );
            AnalyticsService.instance.addedToCart(dish, quantity);
            CartFlyAnimation.runFrom(fromContext: context, imageUrl: dish.imageUrl);
            // Stays on the page — the customer might still add dishes from
            // the "more from this category" shelf below.
          },
        ),
      ),
    );
  }
}

class _RelatedDishes extends StatelessWidget {
  const _RelatedDishes({
    required this.dish,
    required this.catalog,
    required this.title,
  });

  final Dish dish;
  final CatalogProvider catalog;
  final String title;

  @override
  Widget build(BuildContext context) {
    final related = catalog
        .forCategory(dish.categoryId)
        .where((d) => d.id != dish.id)
        .toList();
    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Text(title, style: AppText.h2.copyWith(fontSize: 22)),
        ),
        DishGrid(
          dishes: related,
          strings: context.s,
          onToggleFavorite: catalog.toggleFavorite,
        ),
        SizedBox(height: 40),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final HugeIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: HugeIcon(icon: icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppText.chip.copyWith(color: AppColors.white, fontSize: 12),
      ),
    );
  }
}
