import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/cart_gift.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/dish.dart';
import '../../core/models/loyalty_gift.dart';

/// The cart the customer is building right now.
///
/// Survives leaving the app. What is written down is only what the customer
/// chose — dish id, variant, quantity, note — never the dish itself: prices
/// and photos change, and a basket restored from last week's copy of the
/// menu would quote a price the kitchen no longer honours. On the way back
/// in the lines are matched against the live menu, and anything taken off
/// the menu since simply does not come back.
///
/// Gifts are deliberately not kept. They cost points, depend on stock and
/// cannot exist without food beside them; re-offering yesterday's gift from
/// a balance that may since have been spent would promise something the
/// server would refuse.
class CartProvider extends ChangeNotifier {
  CartProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _storageKey = 'cart.items';

  final SharedPreferences? _prefs;
  final List<CartItem> _items = [];

  /// Called after every change, with the lines as they now stand. Wired to
  /// the reminder in main.dart — the provider itself has no business knowing
  /// about notifications.
  void Function(List<CartItem> items)? onChanged;

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

  /// Every mutation ends here: persist, tell the screens, tell the reminder.
  /// One place, so a new operation cannot forget one of the three.
  void _changed() {
    _persist();
    notifyListeners();
    onChanged?.call(items);
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final payload = [
      for (final item in _items)
        {
          'dishId': item.dish.id,
          if (item.variant != null) 'variantId': item.variant!.id,
          'quantity': item.quantity,
          if (item.note != null && item.note!.isNotEmpty) 'note': item.note,
        },
    ];
    unawaited(
      Future<void>.sync(
        () => prefs.setString(_storageKey, jsonEncode(payload)),
      ),
    );
  }

  /// Rebuilds the saved basket against the menu that just loaded.
  ///
  /// Safe to call more than once — it does nothing once the customer has a
  /// basket of their own, so a catalogue refresh mid-session never
  /// resurrects a line they had just removed.
  void restore(List<Dish> menu) {
    if (_items.isNotEmpty) return;
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || menu.isEmpty) return;
    try {
      final saved = jsonDecode(raw);
      if (saved is! List) {
        _changed();
        return;
      }
      final byId = {for (final dish in menu) dish.id: dish};
      for (final entry in saved) {
        if (entry is! Map) continue;
        final dish = byId[entry['dishId']];
        // Off the menu since: the line is dropped rather than restored as
        // something the kitchen can no longer make.
        if (dish == null) continue;
        final variantId = entry['variantId'];
        final variant = variantId == null
            ? null
            : dish.variants.where((v) => v.id == variantId).firstOrNull;
        // A variant that no longer exists changes the price, so that line
        // goes too rather than falling back to the base dish.
        if (variantId != null && variant == null) continue;
        final quantity = (entry['quantity'] as num?)?.toInt() ?? 1;
        if (quantity < 1) continue;
        _items.add(
          CartItem(
            dish: dish,
            variant: variant,
            quantity: quantity,
            note: entry['note'] as String?,
          ),
        );
      }
    } catch (_) {
      // A basket that cannot be read is not worth crashing — or continuing
      // to remind the customer about every evening.
      _changed();
      return;
    }
    // Also persist the empty result. If every saved dish or variant left the
    // live menu, this clears the stale payload and cancels its old repeating
    // reminder instead of letting either return on the next launch.
    _changed();
  }

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
    _changed();
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
    _changed();
  }

  void remove(Dish dish, {DishVariant? variant}) {
    _items.removeWhere(
      (i) => i.dish.id == dish.id && i.variant?.id == variant?.id,
    );
    // Taking out the last dish takes the gifts with it: a gift-only basket
    // is one the server will not price, and silently keeping them would
    // show the customer a cart they cannot order.
    if (_items.isEmpty) _gifts.clear();
    _changed();
  }

  void clear() {
    _items.clear();
    _gifts.clear();
    _changed();
  }

  // ─── Gifts ───────────────────────────────────────────────────
  //
  // Kept in their own list, never folded into [_items]. A gift costs points
  // rather than manat, and the surest way to keep it out of [subtotal] and
  // out of every money total downstream is for it never to be a [CartItem]
  // in the first place.

  final List<CartGift> _gifts = [];

  List<CartGift> get gifts => List.unmodifiable(_gifts);
  bool get hasGifts => _gifts.isNotEmpty;

  /// What the chosen gifts cost in points. For display only — the server
  /// prices the order and its number is the one that gets charged.
  int get giftPoints => _gifts.fold(0, (sum, g) => sum + g.totalPoints);

  /// The API's own limits, enforced here so the customer is stopped by a
  /// disabled button rather than by a 400 after they have committed.
  static const int maxDistinctGifts = 10;
  static const int maxGiftQuantity = 10;

  /// A gift rides along with food; it is never an order of its own. This is
  /// the rule behind the disabled state on the gift shop's add button.
  bool get canAddGifts => _items.isNotEmpty;

  CartGift? _giftLineFor(String giftId) {
    for (final line in _gifts) {
      if (line.gift.id == giftId) return line;
    }
    return null;
  }

  int giftQuantityOf(String giftId) => _giftLineFor(giftId)?.quantity ?? 0;

  /// Adds one of [gift], or bumps an existing line. Returns false when the
  /// cart has no food yet, when a tenth distinct gift would be added, or
  /// when the line is already at ten — the caller shows why.
  bool addGift(LoyaltyGift gift, {int quantity = 1}) {
    if (!canAddGifts) return false;
    if (quantity < 1) return false;
    final existing = _giftLineFor(gift.id);
    if (existing == null) {
      if (_gifts.length >= maxDistinctGifts) return false;
      if (quantity > maxGiftQuantity) return false;
      _gifts.add(CartGift(gift: gift, quantity: quantity));
    } else {
      final wanted = existing.quantity + quantity;
      if (wanted > maxGiftQuantity) return false;
      existing.quantity = wanted;
    }
    _changed();
    return true;
  }

  void setGiftQuantity(String giftId, int quantity) {
    if (quantity <= 0) {
      removeGift(giftId);
      return;
    }
    final existing = _giftLineFor(giftId);
    if (existing == null) return;
    existing.quantity = quantity > maxGiftQuantity ? maxGiftQuantity : quantity;
    _changed();
  }

  void removeGift(String giftId) {
    _gifts.removeWhere((g) => g.gift.id == giftId);
    _changed();
  }

  /// Drops the gifts but keeps the food — for the moment the last dish is
  /// removed from a cart that still had gifts in it. Leaving them would be
  /// a basket the server refuses to price.
  void dropGiftsIfNoFood() {
    if (_items.isNotEmpty || _gifts.isEmpty) return;
    _gifts.clear();
    _changed();
  }
}
