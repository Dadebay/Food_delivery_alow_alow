import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../order_provider.dart';

/// Five tappable stars once an order is delivered — shown on the order
/// detail screen and the live tracking screen alike.
///
/// Iconly's filled and outline star, not the app's usual HugeIcons set:
/// that set ships stroke weights only, and a rating is read at a glance from
/// a block of colour — a thin outline all but disappears on a white card.
class OrderRatingRow extends StatelessWidget {
  const OrderRatingRow({super.key, required this.order, required this.strings});

  final CustomerOrder order;
  final AppStrings strings;

  static const _filled = IconlyBold.star;
  static const _empty = IconlyLight.star;

  @override
  Widget build(BuildContext context) {
    final rated = order.rating;

    if (rated != null) {
      return Row(
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rated ? _filled : _empty,
              size: 24,
              color: i <= rated ? AppColors.gold : AppColors.divider,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.rateSaved,
              style: AppText.bodyMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.rateDelivery,
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              // A star is a small target, so the tap area is padded out well
              // past the glyph rather than sitting tight around it.
              InkResponse(
                onTap: () => context.read<OrderProvider>().rate(order, i),
                radius: 24,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: Icon(_empty, size: 32, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
