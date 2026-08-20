import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dish.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cart_fly_animation.dart';
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
                            // The add control expands after the first tap.
                            // Keep the title to one stable line so it never
                            // competes with the price below while that happens.
                            Text(
                              dish.name,
                              style: AppText.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

/// A raised plus button until the dish is in the cart, then a compact
/// −/quantity/+ pill. The control changes its surface, shadow and width
/// together, which makes the first add feel intentional instead of like a
/// sudden replacement of two unrelated buttons.
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.dish});

  final Dish dish;

  static const _height = 38.0;
  static const _addWidth = 38.0;
  static const _stepperWidth = 86.0;
  static const _radius = 13.0;

  @override
  Widget build(BuildContext context) {
    final quantity = context.select<CartProvider, int>(
      (cart) => cart.quantityOf(dish),
    );
    final cart = context.read<CartProvider>();

    final inCart = quantity > 0;

    // The stepper has an Expanded quantity label, so it must always receive
    // a finite width. Letting AnimatedSwitcher derive that width from a
    // changing child leaves its outgoing FadeTransition unconstrained and
    // causes "RenderBox was not laid out" during the first add animation.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: inCart ? _stepperWidth : _addWidth,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: inCart
                ? AppColors.orange.withValues(alpha: 0.14)
                : AppColors.orange.withValues(alpha: 0.38),
            blurRadius: inCart ? 8 : 14,
            offset: Offset(0, inCart ? 3 : 5),
          ),
        ],
      ),
      child: Material(
        color: inCart ? AppColors.orangeSoft : AppColors.orange,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: inCart
              ? _Stepper(
                  key: const ValueKey('stepper'),
                  quantity: quantity,
                  onDecrease: () => cart.setQuantity(dish, quantity - 1),
                  onIncrease: () {
                    cart.add(dish);
                    AnalyticsService.instance.addedToCart(dish, 1);
                    CartFlyAnimation.runFrom(
                      fromContext: context,
                      imageUrl: dish.imageUrl,
                    );
                  },
                )
              : _AddButton(
                  key: const ValueKey('add'),
                  onTap: () {
                    cart.add(dish);
                    AnalyticsService.instance.addedToCart(dish, 1);
                    CartFlyAnimation.runFrom(
                      fromContext: context,
                      imageUrl: dish.imageUrl,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const SizedBox(
        width: _QuickAdd._addWidth,
        height: _QuickAdd._height,
        child: Center(
          child: HugeIcon(
            icon: AppIcons.plus,
            color: AppColors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _QuickAdd._height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepTap(
            // One below the last unit reads as "remove", so it gets the
            // bin rather than a minus the customer might not expect to empty
            // the line.
            icon: quantity == 1 ? AppIcons.delete : AppIcons.minus,
            onTap: onDecrease,
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(quantity),
              tween: Tween(begin: 1.18, end: 1.0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: AppText.button.copyWith(
                  fontSize: 14,
                  color: AppColors.orange,
                ),
              ),
            ),
          ),
          _StepTap(icon: AppIcons.plus, onTap: onIncrease),
        ],
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
        width: 26,
        height: _QuickAdd._height,
        child: Center(
          child: HugeIcon(icon: icon, color: AppColors.orange, size: 16),
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
