import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// The customer-visible slice of the order life-cycle (proposal, slide 4 and
/// the `cust_track.png` mock-up): submitted → operator accepted → kitchen
/// done → courier on the way → delivered.
enum OrderStatus {
  /// Just submitted, waiting for the operator to pick it up.
  placed('placed'),

  /// "Оператор принял".
  accepted('accepted'),

  /// "Приготовлено на кухне".
  cooked('cooked'),

  /// "Курьер в пути" — courier assigned and driving.
  onTheWay('on_the_way'),

  /// "Доставлено".
  delivered('delivered'),

  cancelled('cancelled');

  const OrderStatus(this.wire);

  final String wire;

  static OrderStatus fromWire(String? value) => switch (value) {
    'NEW' => OrderStatus.placed,
    'CONFIRMED' => OrderStatus.accepted,
    'SENT_TO_KITCHEN' || 'COOKING' || 'READY' => OrderStatus.cooked,
    'ASSIGNED_TO_COURIER' || 'OUT_FOR_DELIVERY' => OrderStatus.onTheWay,
    'DELIVERED' ||
    'CASH_RETURNED' ||
    'COMPLETED' ||
    'RECONCILED' => OrderStatus.delivered,
    'CANCELLED' => OrderStatus.cancelled,
    _ => OrderStatus.values.firstWhere(
      (status) => status.wire == value,
      orElse: () => OrderStatus.placed,
    ),
  };

  bool get isOpen =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  /// Whether the live map/courier marker makes sense to show yet.
  bool get courierVisible => this == OrderStatus.onTheWay;

  Color get color => switch (this) {
    OrderStatus.placed => AppColors.textMuted,
    OrderStatus.accepted => AppColors.gold,
    OrderStatus.cooked => AppColors.greenLight,
    OrderStatus.onTheWay => AppColors.orange,
    OrderStatus.delivered => AppColors.greenLight,
    OrderStatus.cancelled => AppColors.red,
  };

  Color get softColor => switch (this) {
    OrderStatus.placed => const Color(0xFFEDEFEE),
    OrderStatus.accepted => AppColors.goldSoft,
    OrderStatus.cooked => const Color(0xFFE3F0E9),
    OrderStatus.onTheWay => AppColors.orangeSoft,
    OrderStatus.delivered => const Color(0xFFE3F0E9),
    OrderStatus.cancelled => AppColors.redSoft,
  };

  /// A glyph for the history card's leading badge, so a status reads at a
  /// glance instead of only through the text chip.
  HugeIconData get icon => switch (this) {
    OrderStatus.placed => AppIcons.history,
    OrderStatus.accepted => AppIcons.checkCircle,
    OrderStatus.cooked => AppIcons.package,
    OrderStatus.onTheWay => AppIcons.courier,
    OrderStatus.delivered => AppIcons.checkDouble,
    OrderStatus.cancelled => AppIcons.cancel,
  };
}
