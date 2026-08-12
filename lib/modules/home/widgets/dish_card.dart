import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dish.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../cart/cart_provider.dart';

/// One dish tile in the home/favorites/category grid.
///
/// A short photo up top with the badges on it, then a white block carrying
/// the name, price and quick-add. Overlaying the text on the photo looked
/// good on a bright, well-shot dish and fell apart on everything else — on
/// white the price and the add button read the same on every card.
///
/// The quick-add is the point of the card: adding shouldn't require opening
/// the detail sheet first, so "+" adds one straight from the grid and then
/// morphs into a stepper. The sheet is still a tap away on the card itself,
/// for notes and larger quantities.
class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.dish,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Dish dish;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  static const _radius = 22.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The shadow lives on this outer, unclipped box — the card itself
      // clips its photo, and a clip can't cast a shadow.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DishThumbnail(dish: dish, borderRadius: BorderRadius.zero),
                    // Just enough shade at the top for the heart and the
                    // discount pill to hold up over a bright photo.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        // gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x3D000000), Colors.transparent], stops: [0.0, 0.5]),
                      ),
                    ),
                    if (dish.hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Badge(text: '-${dish.discountPercent}%'),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _FavoriteButton(
                        active: dish.isFavorite,
                        onTap: onToggleFavorite,
                      ),
                    ),
                  ],
                ),
              ),
              // Name and price stack on the left with the quick-add beside
              // them, not under — the white strip is short, and one row of
              // three things fits where three stacked rows don't.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Flexible, so a long name gives up its second
                            // line before the card overflows.
                            Flexible(
                              child: Text(
                                dish.name,
                                style: AppText.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _Price(dish: dish),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _QuickAdd(dish: dish),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            Fmt.money(dish.discountedPrice),
            style: AppText.figure.copyWith(fontSize: 15),
          ),
          if (dish.hasDiscount) ...[
            const SizedBox(width: 5),
            Text(
              Fmt.money(dish.price),
              style: AppText.bodyMuted.copyWith(
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+" until the dish is in the cart, then a compact −/qty/+ stepper. The
/// whole control pops on every quantity change so a tap is felt as well as
/// seen — the grid is where most adding happens, so it gets the feedback.
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.dish});

  final Dish dish;

  static const _size = 34.0;
  static const _radius = 11.0;

  @override
  Widget build(BuildContext context) {
    final quantity = context.select<CartProvider, int>(
      (cart) => cart.quantityOf(dish),
    );
    final cart = context.read<CartProvider>();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: TweenAnimationBuilder<double>(
        // Re-keying on the quantity restarts the pop every time it changes.
        key: ValueKey(quantity),
        tween: Tween(begin: quantity == 0 ? 1.0 : 1.22, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: quantity == 0
            ? _AddButton(
                onTap: () {
                  cart.add(dish);
                  AnalyticsService.instance.addedToCart(dish, 1);
                },
              )
            : _Stepper(
                quantity: quantity,
                onDecrease: () => cart.setQuantity(dish, quantity - 1),
                onIncrease: () {
                  cart.add(dish);
                  AnalyticsService.instance.addedToCart(dish, 1);
                },
              ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_QuickAdd._radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(_QuickAdd._radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: _QuickAdd._size,
            height: _QuickAdd._size,
            child: Center(
              child: HugeIcon(
                icon: AppIcons.plus,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    // A Material of its own, not a decorated Container — otherwise the tap
    // ripples land on the card's Material underneath and never show.
    return Material(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(_QuickAdd._radius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _QuickAdd._size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepTap(
              // One below the last unit reads as "remove", so it gets the
              // bin rather than a minus the customer might not expect to
              // empty the line.
              icon: quantity == 1 ? AppIcons.delete : AppIcons.minus,
              onTap: onDecrease,
            ),
            ConstrainedBox(
              // Grows for a two- or three-digit quantity rather than
              // clipping.
              constraints: const BoxConstraints(minWidth: 25),
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppText.button.copyWith(
                  fontSize: 14,
                  color: AppColors.white,
                ),
              ),
            ),
            _StepTap(icon: AppIcons.plus, onTap: onIncrease),
          ],
        ),
      ),
    );
  }
}

class _StepTap extends StatelessWidget {
  const _StepTap({required this.icon, required this.onTap});

  final HugeIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        // Narrow on purpose — the stepper shares a cramped row with the
        // name and price, and every pixel it gives back is one they keep.
        width: 25,
        height: _QuickAdd._size,
        child: Center(
          child: HugeIcon(icon: icon, color: AppColors.white, size: 15),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
        style: AppText.chip.copyWith(color: AppColors.white, fontSize: 11),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Slightly translucent rather than solid white — reads as glass on
      // the photo instead of a disc punched out of it.
      color: Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(
          color: AppColors.white.withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7).copyWith(top: 9),
          child: SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Only present while active, so it's built fresh — and
                // plays once — every time the heart turns on, rather than
                // replaying on unrelated rebuilds.
                if (active)
                  TweenAnimationBuilder<double>(
                    key: const ValueKey('burst'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOut,
                    builder: (context, t, child) => Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(
                        scale: 1 + t * 1.6,
                        child: const Icon(
                          Icons.favorite,
                          color: AppColors.orange,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  key: ValueKey(active),
                  tween: Tween(begin: active ? 1.35 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  // HugeIcons only ships the outline heart — favoriting
                  // swaps to Material's solid one instead of just
                  // recolouring the outline, so the change is a shape the
                  // eye catches, not just a tint.
                  child: active
                      ? const Icon(
                          Icons.favorite,
                          color: AppColors.orange,
                          size: 18,
                        )
                      : HugeIcon(
                          icon: AppIcons.favorite,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
