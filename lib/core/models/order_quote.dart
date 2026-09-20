import '../constants/app_config.dart';

/// The authoritative pricing for the current cart — mirrors `POST
/// /orders/quote`, which recomputes item prices, the promo discount and the
/// delivery fee server-side from scratch. Nothing here is derived on the
/// client; every field is exactly what the server would charge if an order
/// were created right now with the same items, promo code and etrap.
class OrderQuote {
  const OrderQuote({
    required this.subtotal,
    required this.discount,
    required this.discountedSubtotal,
    required this.deliveryFee,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double discountedSubtotal;
  final double deliveryFee;
  final double total;

  /// Priced on the client, for the moments the quote endpoint cannot be
  /// reached. The delivery fee is [AppConfig.fallbackDeliveryFee] and any
  /// applied promo is left out — a discount this app invented would be a
  /// promise it cannot keep. The server prices the order again at creation
  /// time regardless, so this only ever drives what is on screen.
  factory OrderQuote.estimate({
    required double subtotal,
    double? deliveryFee,
  }) {
    final fee = deliveryFee ?? AppConfig.fallbackDeliveryFee;
    return OrderQuote(
      subtotal: subtotal,
      discount: 0,
      discountedSubtotal: subtotal,
      deliveryFee: fee,
      total: subtotal + fee,
    );
  }

  factory OrderQuote.fromJson(Map<String, dynamic> json) => OrderQuote(
    subtotal: (json['subtotal'] as num).toDouble(),
    discount: (json['discount'] as num).toDouble(),
    discountedSubtotal: (json['discountedSubtotal'] as num).toDouble(),
    deliveryFee: (json['deliveryFee'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
  );
}
