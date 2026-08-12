import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/order.dart';
import '../../../core/models/order_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../../core/widgets/order_status_chip.dart';
import 'order_status_badge.dart';

/// One past or in-progress order — number, date, item summary, status, total
/// and a one-tap "Повторить" that puts everything back in the cart.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.order, required this.strings, required this.onTap, required this.onReorder});

  final CustomerOrder order;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final status = order.status;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        // The screen behind this is nearly the same white as the card, so
        // without a shadow the card has no visible edge at all — this is
        // what makes it read as a raised card instead of disappearing into
        // the background.
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    OrderStatusBadge(status: status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.orderNumber(order.number), style: AppText.h2.copyWith(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(Fmt.date(order.placedAt), style: AppText.bodyMuted.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusChip(status: status, strings: strings),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ItemThumbnails(items: order.items),
                    const Spacer(),
                    if (!status.isOpen)
                      _ReorderButton(label: strings.reorder, onTap: onReorder)
                    else if (status == OrderStatus.onTheWay && order.etaMinutesLow != null && order.etaMinutesHigh != null)
                      _EtaHint(text: strings.etaRange(order.etaMinutesLow!, order.etaMinutesHigh!))
                    else
                      // The same status glyph as the badge up top — a clock
                      // for a fresh order, a courier once it's on the way,
                      // a double-check once delivered — instead of a plain
                      // chevron that says nothing about where it stands.
                      HugeIcon(icon: status.icon, color: status.color, size: 18),
                    const SizedBox(width: 10),
                    _PriceBadge(text: Fmt.money(order.total)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The order total, in its own soft rounded pill — echoes the circular
/// thumbnails next to it rather than sitting as bare text against the card.
class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: AppText.figure.copyWith(fontSize: 15)),
    );
  }
}

/// The order's dishes as a row of overlapping circular photos — reads at a
/// glance the way a shelf of the actual food does, instead of a line of
/// names that only says something once you've read all of it.
class _ItemThumbnails extends StatelessWidget {
  const _ItemThumbnails({required this.items});

  final List<CartItem> items;

  static const double _size = 48;
  static const double _overlap = 16;
  static const int _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(_maxShown).toList();
    final extra = items.length - shown.length;
    final circleCount = shown.length + (extra > 0 ? 1 : 0);
    if (circleCount == 0) return const SizedBox.shrink();
    final width = _size + (circleCount - 1) * (_size - _overlap);

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: _ThumbnailCircle(
                child: DishThumbnail(dish: shown[i].dish, borderRadius: BorderRadius.circular(_size)),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (_size - _overlap),
              child: _ThumbnailCircle(
                child: ColoredBox(
                  color: AppColors.cream,
                  child: Center(
                    child: Text(
                      '+$extra',
                      style: AppText.chip.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailCircle extends StatelessWidget {
  const _ThumbnailCircle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ItemThumbnails._size,
      height: _ItemThumbnails._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipOval(child: child),
    );
  }
}

class _EtaHint extends StatelessWidget {
  const _EtaHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HugeIcon(icon: AppIcons.courier, color: AppColors.orange, size: 16),
        const SizedBox(width: 6),
        Text(text, style: AppText.chip.copyWith(color: AppColors.orange, fontSize: 13)),
      ],
    );
  }
}

class _ReorderButton extends StatelessWidget {
  const _ReorderButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(icon: AppIcons.cart, color: AppColors.green, size: 15),
              const SizedBox(width: 6),
              Text(label, style: AppText.chip.copyWith(color: AppColors.green)),
            ],
          ),
        ),
      ),
    );
  }
}
