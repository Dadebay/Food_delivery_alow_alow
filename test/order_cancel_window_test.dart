import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/cart_item.dart';
import 'package:food_delivery/core/models/delivery_address.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/core/models/order.dart';
import 'package:food_delivery/core/models/order_status.dart';
import 'package:latlong2/latlong.dart';

CustomerOrder _orderPlacedAt(DateTime placedAt, {OrderStatus status = OrderStatus.placed}) {
  return CustomerOrder(
    id: 'ord-test',
    number: 1,
    status: status,
    items: [CartItem(dish: Dish(id: 'd1', name: 'Test dish', description: '', price: 10, categoryId: 'c1'))],
    address: const DeliveryAddress(district: '1', house: '1', point: LatLng(37.96, 58.32)),
    subtotal: 10,
    deliveryFee: 5,
    placedAt: placedAt,
  );
}

void main() {
  group('CustomerOrder.isCancellable (15-minute self-cancel window)', () {
    test('true right after placing', () {
      final order = _orderPlacedAt(DateTime.now());
      expect(order.isCancellable, isTrue);
    });

    test('true just under 15 minutes', () {
      final order = _orderPlacedAt(DateTime.now().subtract(const Duration(minutes: 14, seconds: 59)));
      expect(order.isCancellable, isTrue);
    });

    test('false just over 15 minutes', () {
      final order = _orderPlacedAt(DateTime.now().subtract(const Duration(minutes: 15, seconds: 1)));
      expect(order.isCancellable, isFalse);
    });

    test('false long after placing', () {
      final order = _orderPlacedAt(DateTime.now().subtract(const Duration(hours: 2)));
      expect(order.isCancellable, isFalse);
    });

    test('still true after the operator accepted, while inside the window', () {
      for (final status in [OrderStatus.accepted, OrderStatus.cooked, OrderStatus.onTheWay]) {
        final order = _orderPlacedAt(DateTime.now(), status: status);
        expect(order.isCancellable, isTrue, reason: '$status');
      }
    });

    test('false past the window even if still in progress', () {
      final late = DateTime.now().subtract(const Duration(minutes: 16));
      for (final status in [OrderStatus.accepted, OrderStatus.cooked, OrderStatus.onTheWay]) {
        final order = _orderPlacedAt(late, status: status);
        expect(order.isCancellable, isFalse, reason: '$status');
      }
    });

    test('false once cancelled/delivered, even within the window', () {
      expect(_orderPlacedAt(DateTime.now(), status: OrderStatus.cancelled).isCancellable, isFalse);
      expect(_orderPlacedAt(DateTime.now(), status: OrderStatus.delivered).isCancellable, isFalse);
    });
  });
}
