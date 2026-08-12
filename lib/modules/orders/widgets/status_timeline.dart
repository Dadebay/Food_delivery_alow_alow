import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/models/order_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

/// The four-step progress list from `cust_track.png`: Оператор принял →
/// Приготовлено на кухне → Курьер в пути → Доставлено.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.order, required this.strings});

  final CustomerOrder order;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        label: strings.statusAccepted,
        time: order.acceptedAt,
        reached: _rank(order.status) >= 1,
        current: order.status == OrderStatus.accepted,
      ),
      (
        label: strings.statusCooked,
        time: order.cookedAt,
        reached: _rank(order.status) >= 2,
        current: order.status == OrderStatus.cooked,
      ),
      (
        label: strings.statusOnTheWay,
        time: null,
        reached: _rank(order.status) >= 3,
        current: order.status == OrderStatus.onTheWay,
      ),
      (
        label: strings.statusDelivered,
        time: order.deliveredAt,
        reached: _rank(order.status) >= 4,
        current: order.status == OrderStatus.delivered,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            label: steps[i].label,
            time: steps[i].time,
            reached: steps[i].reached,
            current: steps[i].current,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  static int _rank(OrderStatus status) => switch (status) {
    OrderStatus.placed => 0,
    OrderStatus.accepted => 1,
    OrderStatus.cooked => 2,
    OrderStatus.onTheWay => 3,
    OrderStatus.delivered => 4,
    OrderStatus.cancelled => 0,
  };
}

/// One step: a dot, a connecting line down to the next dot (so the list
/// reads as a single path being walked rather than a disconnected
/// checklist), and the label row.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.reached,
    required this.current,
    required this.isLast,
  });

  final String label;
  final DateTime? time;
  final bool reached;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _Dot(reached: reached, current: current),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: reached ? AppColors.greenLight : AppColors.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.body.copyWith(
                        fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                        color: reached ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (current)
                    Text(
                      '—',
                      style: AppText.bodyMuted.copyWith(color: AppColors.orange),
                    )
                  else if (time != null)
                    Text(Fmt.time(time!), style: AppText.bodyMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.reached, required this.current});

  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current
        ? AppColors.orange
        : (reached ? AppColors.greenLight : AppColors.divider);

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? AppColors.orangeSoft
            : (reached ? color.withValues(alpha: 0.15) : Colors.transparent),
        border: Border.all(color: color, width: 2),
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: reached && !current
          ? const Center(
              child: HugeIcon(
                icon: AppIcons.check,
                color: AppColors.greenLight,
                size: 14,
              ),
            )
          : null,
    );
  }
}
