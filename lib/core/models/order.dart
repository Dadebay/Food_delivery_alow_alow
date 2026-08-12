import 'package:latlong2/latlong.dart';

import 'cart_item.dart';
import 'delivery_address.dart';
import 'order_status.dart';

/// One order the customer placed — from checkout through the tracking screen
/// to the rating prompt.
class CustomerOrder {
  CustomerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.items,
    required this.address,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0,
    this.changeFrom,
    required this.placedAt,
    this.acceptedAt,
    this.cookedAt,
    this.deliveredAt,
    this.courierName,
    this.courierPhone,
    this.courierPoint,
    this.branchPoint,
    this.branchName,
    this.etaMinutesLow,
    this.etaMinutesHigh,
    this.rating,
  });

  final String id;
  final int number;
  OrderStatus status;

  final List<CartItem> items;
  final DeliveryAddress address;

  final double subtotal;
  final double deliveryFee;
  final double discount;

  /// "Сдача с какой суммы" — `null` means no change needed.
  final double? changeFrom;

  final DateTime placedAt;
  DateTime? acceptedAt;
  DateTime? cookedAt;
  DateTime? deliveredAt;

  /// Populated once a courier is assigned.
  String? courierName;
  String? courierPhone;
  LatLng? courierPoint;
  LatLng? branchPoint;
  String? branchName;

  /// The driving route from the branch to the address — runtime-only state,
  /// not sent to or read from the server. The courier marker moves along
  /// these exact points rather than a straight line, so it visibly follows
  /// the drawn route.
  List<LatLng>? routePoints;

  int? etaMinutesLow;
  int? etaMinutesHigh;

  /// 1–5 once the customer rates the delivery; `null` before that.
  int? rating;

  double get total => subtotal + deliveryFee - discount;

  double? get changeDue => changeFrom == null
      ? null
      : (changeFrom! - total).clamp(0, double.infinity);

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}
