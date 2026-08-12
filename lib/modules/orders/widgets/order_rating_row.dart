import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../order_provider.dart';

/// Five tappable stars once an order is delivered — shown on the order
/// detail screen and the live tracking screen alike.
class OrderRatingRow extends StatelessWidget {
  const OrderRatingRow({super.key, required this.order, required this.strings});

  final CustomerOrder order;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;

    if (order.rating != null) {
      return Row(
        children: [
          for (var i = 1; i <= 5; i++)
            HugeIcon(
              icon: AppIcons.star,
              size: 22,
              color: i <= order.rating! ? AppColors.gold : AppColors.divider,
            ),
          const SizedBox(width: 10),
          Text(s.rateSaved, style: AppText.bodyMuted),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.rateDelivery,
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              InkWell(
                onTap: () => context.read<OrderProvider>().rate(order, i),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: HugeIcon(
                    icon: AppIcons.star,
                    size: 28,
                    color: AppColors.divider,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
