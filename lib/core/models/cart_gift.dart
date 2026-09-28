import 'loyalty_gift.dart';

/// A gift the customer picked, waiting in the cart alongside the food.
///
/// Deliberately not a [CartItem]: a gift has no manat price, is capped at ten
/// of each, and cannot exist in a cart with no food in it. Keeping the two
/// lists apart is what stops a gift from ever reaching a money subtotal.
class CartGift {
  CartGift({required this.gift, this.quantity = 1});

  final LoyaltyGift gift;
  int quantity;

  /// What this line costs in points. Shown for clarity only — the server
  /// prices the whole order and its own number is the one that is charged.
  int get totalPoints => gift.pointsCost * quantity;

  Map<String, dynamic> toJson() => {
    'giftId': gift.id,
    'quantity': quantity,
  };
}
