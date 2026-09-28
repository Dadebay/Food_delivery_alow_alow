import '../utils/json_number.dart';
import '../constants/app_config.dart';

/// One gift as the server priced it inside a quote or a placed order.
///
/// Carries its own name, photo and cost rather than pointing at a
/// [LoyaltyGift]: this is a snapshot of the moment it was ordered, and the
/// gift catalogue moves underneath it. An order from last week must still
/// show what was actually chosen even after the admin hides it or changes
/// its price.
class QuotedGift {
  const QuotedGift({
    required this.giftId,
    required this.name,
    required this.quantity,
    required this.pointsCost,
    required this.totalPoints,
    this.imageUrl,
  });

  final String giftId;
  final String name;
  final int quantity;
  final int pointsCost;
  final int totalPoints;
  final String? imageUrl;

  factory QuotedGift.fromJson(
    Map<String, dynamic> json, {
    String? Function(Object?)? resolveImage,
  }) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final cost = (json['pointsCost'] as num?)?.toInt() ?? 0;
    return QuotedGift(
      giftId: (json['giftId'] ?? json['id']).toString(),
      name: json['name'] as String? ?? '',
      quantity: quantity,
      pointsCost: cost,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? cost * quantity,
      imageUrl: resolveImage == null
          ? json['imageUrl'] as String?
          : resolveImage(json['imageUrl']),
    );
  }
}

/// One priced cart line, as the server totalled it.
class QuotedItem {
  const QuotedItem({this.productId, this.quantity, this.loyaltyPoints});

  final String? productId;
  final int? quantity;

  /// Points for the whole line — the server has already multiplied the
  /// dish's per-unit value by [quantity]. This is what the cart shows; a
  /// dish card shows the per-unit `Dish.loyaltyPoints` instead.
  final int? loyaltyPoints;

  factory QuotedItem.fromJson(Map<String, dynamic> json) => QuotedItem(
    productId: json['productId']?.toString(),
    quantity: (json['quantity'] as num?)?.toInt(),
    loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt(),
  );
}

/// The authoritative pricing for the current cart — mirrors `POST
/// /orders/quote`, which recomputes item prices, the promo discount and the
/// delivery fee server-side from scratch. Nothing here is derived on the
/// client; every field is exactly what the server would charge if an order
/// were created right now with the same items, gifts, promo code and etrap.
///
/// Everything loyalty-related is nullable on purpose. The endpoint predates
/// those fields, and an app that required them would break against a server
/// that has not been updated yet — see the release-boundary note in
/// `MOBILE_LOYALTY_DELIVERY_HANDOFF.md`. Null means "this server does not
/// do points", which the UI renders as nothing at all rather than as zero.
class OrderQuote {
  const OrderQuote({
    required this.subtotal,
    required this.discount,
    required this.discountedSubtotal,
    required this.deliveryFee,
    required this.total,
    this.items = const [],
    this.gifts = const [],
    this.loyaltyPointsEarned,
    this.loyaltyPointsSpent,
    this.pointsBalance,
  });

  final double subtotal;
  final double discount;
  final double discountedSubtotal;
  final double deliveryFee;
  final double total;

  final List<QuotedItem> items;

  /// The gifts as the server accepted them. Their cost is in points and is
  /// never part of [total], which is money.
  final List<QuotedGift> gifts;

  /// Points this order will earn — credited only after `DELIVERED`, so it
  /// must be presented as a future amount, not as balance the customer has.
  final int? loyaltyPointsEarned;

  /// Points the gifts in this order will cost.
  final int? loyaltyPointsSpent;

  /// The balance the server sees right now, echoed back so checkout does not
  /// have to re-read `/loyalty/me` to show it.
  final int? pointsBalance;

  /// True when this server priced the order with loyalty at all. Screens use
  /// it to decide whether to draw the points block, instead of testing each
  /// field for null in half a dozen places.
  bool get hasLoyalty =>
      loyaltyPointsEarned != null ||
      loyaltyPointsSpent != null ||
      pointsBalance != null ||
      gifts.isNotEmpty;

  /// Priced on the client, for the moments the quote endpoint cannot be
  /// reached. The delivery fee is [AppConfig.fallbackDeliveryFee] and any
  /// applied promo is left out — a discount this app invented would be a
  /// promise it cannot keep. The server prices the order again at creation
  /// time regardless, so this only ever drives what is on screen.
  ///
  /// It carries no loyalty numbers: guessing what an order will earn, or
  /// what a gift will cost, is exactly the arithmetic the server owns.
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

  factory OrderQuote.fromJson(
    Map<String, dynamic> json, {
    String? Function(Object?)? resolveImage,
  }) => OrderQuote(
    subtotal: readDouble(json['subtotal']) ?? 0,
    discount: readDouble(json['discount']) ?? 0,
    discountedSubtotal: readDouble(json['discountedSubtotal']) ?? 0,
    deliveryFee: readDouble(json['deliveryFee']) ?? 0,
    total: readDouble(json['total']) ?? 0,
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(QuotedItem.fromJson)
        .toList(),
    gifts: (json['gifts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => QuotedGift.fromJson(e, resolveImage: resolveImage))
        .toList(),
    loyaltyPointsEarned: (json['loyaltyPointsEarned'] as num?)?.toInt(),
    loyaltyPointsSpent: (json['loyaltyPointsSpent'] as num?)?.toInt(),
    pointsBalance: (json['pointsBalance'] as num?)?.toInt(),
  );
}
