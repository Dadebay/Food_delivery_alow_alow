import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/modules/cart/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const variant = DishVariant(id: 'large', name: 'Large', price: 42);
  final kebab = Dish(
    id: 'kebab',
    name: 'Kebab',
    description: '',
    price: 30,
    categoryId: 'grill',
  );
  final pizza = Dish(
    id: 'pizza',
    name: 'Pizza',
    description: '',
    price: 35,
    categoryId: 'bakery',
    pricingType: DishPricingType.variant,
    variants: const [variant],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'restores quantity, variant, and note from the live catalogue',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final firstSession = CartProvider(prefs: prefs);
      firstSession.add(kebab, quantity: 2, note: 'No onion');
      firstSession.add(pizza, variant: variant, quantity: 3);

      final restored = CartProvider(prefs: prefs);
      List<int>? reportedQuantities;
      restored.onChanged = (items) {
        reportedQuantities = items.map((item) => item.quantity).toList();
      };
      restored.restore([kebab, pizza]);

      expect(restored.items, hasLength(2));
      expect(restored.items[0].dish, same(kebab));
      expect(restored.items[0].quantity, 2);
      expect(restored.items[0].note, 'No onion');
      expect(restored.items[1].dish, same(pizza));
      expect(restored.items[1].variant, same(variant));
      expect(restored.items[1].quantity, 3);
      expect(reportedQuantities, [2, 3]);
    },
  );

  test(
    'drops unavailable lines and clears their stale reminder state',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cart.items',
        jsonEncode([
          {'dishId': 'removed', 'quantity': 1},
        ]),
      );

      final restored = CartProvider(prefs: prefs);
      List<int>? reportedQuantities;
      restored.onChanged = (items) {
        reportedQuantities = items.map((item) => item.quantity).toList();
      };
      restored.restore([kebab]);

      expect(restored.items, isEmpty);
      expect(reportedQuantities, isEmpty);
      expect(jsonDecode(prefs.getString('cart.items')!), isEmpty);
    },
  );

  test(
    'clear persists an empty cart and reports it for reminder cancellation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final cart = CartProvider(prefs: prefs)..add(kebab);
      List<int>? reportedQuantities;
      cart.onChanged = (items) {
        reportedQuantities = items.map((item) => item.quantity).toList();
      };

      cart.clear();

      expect(reportedQuantities, isEmpty);
      expect(jsonDecode(prefs.getString('cart.items')!), isEmpty);
    },
  );
}
