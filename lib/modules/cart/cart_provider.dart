import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
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

  double get deliveryFee =>
      _items.isEmpty ? 0 : AppConfig.deliveryFeeFor(subtotal);

  double get total => subtotal + deliveryFee;

  /// Existing line for this dish, if the customer already added it — adding
  /// again bumps the quantity instead of creating a duplicate row.
  CartItem? _lineFor(Dish dish) {
    for (final item in _items) {
      if (item.dish.id == dish.id) return item;
    }
    return null;
  }

  int quantityOf(Dish dish) => _lineFor(dish)?.quantity ?? 0;

  void add(Dish dish, {int quantity = 1, String? note}) {
    final existing = _lineFor(dish);
    if (existing != null) {
      existing.quantity += quantity;
      if (note != null && note.isNotEmpty) existing.note = note;
    } else {
      _items.add(CartItem(dish: dish, quantity: quantity, note: note));
    }
    notifyListeners();
  }

  void setQuantity(Dish dish, int quantity) {
    if (quantity <= 0) {
      remove(dish);
      return;
    }
    final existing = _lineFor(dish);
    if (existing == null) return;
    existing.quantity = quantity;
    notifyListeners();
  }

  void remove(Dish dish) {
    _items.removeWhere((i) => i.dish.id == dish.id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
