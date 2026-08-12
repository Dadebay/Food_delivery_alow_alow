import 'dish.dart';

/// One line in the cart — a dish, how many, and any note for the kitchen
/// ("без лука", "поострее").
class CartItem {
  CartItem({required this.dish, this.quantity = 1, this.note});

  final Dish dish;
  int quantity;
  String? note;

  double get lineTotal => dish.discountedPrice * quantity;
}
