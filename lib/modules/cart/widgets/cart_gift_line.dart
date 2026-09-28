import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/cart_gift.dart';
import '../../../core/services/catalog_image_cache_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';

/// A chosen gift, sitting in the cart beside the food.
///
/// Deliberately the same card as [CartLine] — same size, same thumbnail, same
/// stepper — because it behaves the same way: the customer adds, counts and
/// removes it exactly as they do a dish. Only the price differs, and that is
/// the one thing drawn differently: points on a gold chip rather than manat,
/// so nobody reads a gift as something they are about to be charged for.
class CartGiftLine extends StatelessWidget {
  const CartGiftLine({
    super.key,
    required this.line,
    required this.strings,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartGift line;
  final AppStrings strings;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  static const _photoSize = 88.0;

  @override
  Widget build(BuildContext context) {
    final imageUrl = line.gift.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _photoSize,
            height: _photoSize,
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null
                ? const Center(
                    child: HugeIcon(
                      icon: AppIcons.gift,
                      color: AppColors.gold,
                      size: 30,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: CatalogImageCacheManager.instance,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Center(
                      child: HugeIcon(
                        icon: AppIcons.gift,
                        color: AppColors.gold,
                        size: 30,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.gift.name,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onRemove,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: HugeIcon(
                          icon: AppIcons.cancel,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // The per-unit cost, matching the dish row's unit price: the
                // line total for points is in the summary below.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    strings.pointsValue(line.gift.pointsCost),
                    style: AppText.chip.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _GiftStepper(
                  quantity: line.quantity,
                  onDecrement: onDecrement,
                  onIncrement: onIncrement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Same control as the dish row's stepper, kept here rather than shared so
/// the food row is free to change without dragging the gift row with it.
class _GiftStepper extends StatelessWidget {
  const _GiftStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  static const _height = 40.0;
  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepTap(
                icon: quantity == 1 ? AppIcons.delete : AppIcons.minus,
                onTap: onDecrement,
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StepTap(icon: AppIcons.plus, onTap: onIncrement),
            ],
          ),
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
        width: 40,
        height: _GiftStepper._height,
        child: Center(
          child: HugeIcon(icon: icon, color: AppColors.onBrand, size: 17),
        ),
      ),
    );
  }
}
