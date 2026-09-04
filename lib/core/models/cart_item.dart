import 'dish.dart';

/// One line in the cart — a dish, how many, and any note for the kitchen
/// ("без лука", "поострее").
class CartItem {
  CartItem({required this.dish, this.variant, this.quantity = 1, this.note});

  final Dish dish;

  /// The size/weight picked when [dish.hasVariants] — `null` for a plain
  /// dish. Two lines for the same dish with different variants stay
  /// separate lines, since they price differently.
  final DishVariant? variant;
  int quantity;
  String? note;

  /// The variant's own price when one is selected — variants aren't
  /// discounted client-side, only the base dish's weekly badge is.
  double get unitPrice => variant?.price ?? dish.discountedPrice;

  double get lineTotal => unitPrice * quantity;

  String get displayName =>
      variant != null && variant!.name.isNotEmpty
          ? '${dish.name} · ${variant!.name}'
          : dish.name;
}
