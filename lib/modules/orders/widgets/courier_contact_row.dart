import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

/// Courier avatar, name and cash/change note, with a one-tap call button —
/// shown on both the order detail screen and the live tracking screen once
/// a courier is assigned.
class CourierContactRow extends StatelessWidget {
  const CourierContactRow({
    super.key,
    required this.order,
    required this.strings,
    required this.onCall,
  });

  final CustomerOrder order;
  final AppStrings strings;
  final Future<void> Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final initials = order.courierName!
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold,
          ),
          child: Text(
            initials,
            style: AppText.button.copyWith(
              color: AppColors.white,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.courierName!,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                order.changeFrom != null
                    ? '${s.changeCourierNote} ${Fmt.money(order.changeFrom!)} · ${s.cashLineTracking(Fmt.money(order.total))}'
                    : s.cashLineTracking(Fmt.money(order.total)),
                style: AppText.bodyMuted.copyWith(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.greenLight,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => onCall(order.courierPhone!),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(13),
              child: HugeIcon(
                icon: AppIcons.call,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
