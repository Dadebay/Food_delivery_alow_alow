import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dish_thumbnail.dart';

/// One row in the cart.
///
/// Photo-led on purpose: the thumbnail is sized up to lead the row, and the
/// price sits small and quiet next to the stepper instead of bold on its
/// own column — the dish should be what catches the eye here, not a running
/// total the customer will see again, larger, in the summary below.
class CartLine extends StatelessWidget {
  const CartLine({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  static const _photoSize = 88.0;

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DishThumbnail(
              dish: item.dish,
              borderRadius: BorderRadius.circular(14),
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
                        item.dish.name,
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
                const SizedBox(height: 3),
                // Unit price, not the running line total — the customer is
                // pricing one dish here, and sees the total already, bigger,
                // in the summary below.
                Text(
                  Fmt.money(item.dish.discountedPrice),
                  style: AppText.bodyMuted.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.note!,
                    style: AppText.bodyMuted.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                _QuantityStepper(
                  quantity: item.quantity,
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

/// One connected pill instead of two floating circles either side of a
/// number — reads as a single control rather than three separate ones.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
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
    // Shadow lives on this outer, unclipped box — the Material below it
    // clips its own corners, and a clip can't cast a shadow.
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
                // One below the last unit reads as "remove", so it gets the
                // bin rather than a minus the customer might not expect to
                // empty the line.
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
        height: _QuantityStepper._height,
        child: Center(
          child: HugeIcon(icon: icon, color: AppColors.green, size: 18),
        ),
      ),
    );
  }
}
