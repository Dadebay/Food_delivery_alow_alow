import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models/order_status.dart';

/// A colour-coded circle with a status glyph — shared between the history
/// card and the order detail screen so a status reads at a glance in both.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status, this.size = 40});

  final OrderStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: status.softColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: HugeIcon(
          icon: status.icon,
          color: status.color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
