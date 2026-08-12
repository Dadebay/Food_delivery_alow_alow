import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/delivery_address.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/core/models/order_status.dart';
import 'package:food_delivery/core/utils/formatters.dart';
import 'package:food_delivery/modules/cart/cart_provider.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Dish dish({
    String id = 'd1',
    double price = 32,
    int? discountPercent,
  }) => Dish(
    id: id,
    name: 'Test dish',
    description: '',
    price: price,
    categoryId: 'somsa',
    discountPercent: discountPercent,
  );

  group('Dish pricing', () {
    test('no discount charges the sticker price', () {
      expect(dish().discountedPrice, 32);
      expect(dish().hasDiscount, isFalse);
    });

    test('discount reduces the charged price but keeps the sticker price', () {
      final d = dish(price: 100, discountPercent: 15);
      expect(d.discountedPrice, 85);
      expect(d.price, 100);
      expect(d.hasDiscount, isTrue);
    });
  });

  group('CartProvider', () {
    test('adding the same dish twice bumps quantity instead of duplicating', () {
      final cart = CartProvider();
      final d = dish();
      cart.add(d, quantity: 2);
      cart.add(d, quantity: 1);
      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 3);
    });

    test('setting quantity to zero removes the line', () {
      final cart = CartProvider();
      final d = dish();
      cart.add(d);
      cart.setQuantity(d, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('discount total reflects only the discounted lines', () {
      final cart = CartProvider();
      cart.add(dish(id: 'a', price: 100, discountPercent: 15), quantity: 2);
      cart.add(dish(id: 'b', price: 50));
      // 100 -> 85 is 15 off per unit, times 2 units.
      expect(cart.discount, 30);
      expect(cart.subtotal, 85 * 2 + 50);
    });

    test('empty cart has no delivery fee; non-empty cart does', () {
      final cart = CartProvider();
      expect(cart.deliveryFee, 0);
      cart.add(dish());
      expect(cart.deliveryFee, greaterThan(0));
    });
  });

  group('OrderStatus', () {
    test('only delivered and cancelled are closed', () {
      expect(OrderStatus.placed.isOpen, isTrue);
      expect(OrderStatus.onTheWay.isOpen, isTrue);
      expect(OrderStatus.delivered.isOpen, isFalse);
      expect(OrderStatus.cancelled.isOpen, isFalse);
    });

    test('courier is only shown on the map once actually on the way', () {
      expect(OrderStatus.cooked.courierVisible, isFalse);
      expect(OrderStatus.onTheWay.courierVisible, isTrue);
      expect(OrderStatus.delivered.courierVisible, isFalse);
    });

    test('unknown wire value falls back to placed rather than throwing', () {
      expect(OrderStatus.fromWire('something_new'), OrderStatus.placed);
      expect(OrderStatus.fromWire(null), OrderStatus.placed);
    });
  });

  group('DeliveryAddress', () {
    test('detail line only includes parts that are present', () {
      const address = DeliveryAddress(
        district: 'Parahat 7',
        house: '12',
        entrance: '3',
        point: LatLng(37.93, 58.41),
      );
      final line = address.detailLine(
        entranceLabel: 'подъезд',
        floorLabel: 'этаж',
        apartmentLabel: 'кв.',
      );
      expect(line, 'подъезд 3');
      expect(line, isNot(contains('этаж')));
    });
  });

  group('formatting', () {
    test('distance under a kilometre switches to metres', () {
      expect(Fmt.km(0.4), '400 m');
      expect(Fmt.km(2.42), '2,4 km');
      expect(Fmt.km(null), '—');
    });

    test('money keeps the currency suffix', () {
      expect(Fmt.money(139), contains('139'));
      expect(Fmt.money(139), endsWith('TMT'));
    });
  });
}
