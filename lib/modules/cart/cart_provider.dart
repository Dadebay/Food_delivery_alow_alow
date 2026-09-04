import 'package:flutter/foundation.dart';

import '../../core/models/cart_item.dart';
import '../../core/models/dish.dart';

/// The cart the customer is building right now. In-memory only — it clears
/// on sign-out or a fresh install, same as the phone number itself.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);

  double get discount => _items.fold(
    0,
    (sum, i) =>
        sum +
        (i.dish.hasDiscount
            ? (i.dish.price - i.dish.discountedPrice) * i.quantity
            : 0),
  );

  // Delivery fee isn't computed here — it's per-district pricing the
  // backend owns (`POST /delivery/quote`, `POST /orders/quote`). Screens
  // that show a delivery-inclusive total read it from `AddressProvider` or
  // an `OrderQuote`, never from this provider.

  /// Existing line for this dish + variant, if the customer already added
  /// it — adding again bumps the quantity instead of creating a duplicate
  /// row. Two different variants of the same dish are two different lines,
  /// since they price differently.
  CartItem? _lineFor(Dish dish, DishVariant? variant) {
    for (final item in _items) {
      if (item.dish.id == dish.id && item.variant?.id == variant?.id) {
        return item;
      }
    }
    return null;
  }

  int quantityOf(Dish dish, {DishVariant? variant}) =>
      _lineFor(dish, variant)?.quantity ?? 0;

  /// Returns false for an invalid product/variant pairing. This is a
  /// defensive invariant for all entry points; the detail UI keeps the action
  /// disabled before an unselected variant is possible in normal use.
  bool add(Dish dish, {DishVariant? variant, int quantity = 1, String? note}) {
    if (dish.hasVariants && (variant == null || !variant.isActive)) {
      return false;
    }
    if (!dish.hasVariants && variant != null) return false;
    final existing = _lineFor(dish, variant);
    if (existing != null) {
      existing.quantity += quantity;
      if (note != null && note.isNotEmpty) existing.note = note;
    } else {
      _items.add(
        CartItem(dish: dish, variant: variant, quantity: quantity, note: note),
      );
    }
    notifyListeners();
    return true;
  }

  void setQuantity(Dish dish, int quantity, {DishVariant? variant}) {
    if (quantity <= 0) {
      remove(dish, variant: variant);
      return;
    }
    final existing = _lineFor(dish, variant);
    if (existing == null) return;
    existing.quantity = quantity;
    notifyListeners();
  }

  void remove(Dish dish, {DishVariant? variant}) {
    _items.removeWhere(
      (i) => i.dish.id == dish.id && i.variant?.id == variant?.id,
    );
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
