import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/delivery_quote.dart';
import 'package:food_delivery/core/models/order_quote.dart';

void main() {
  test('order quote accepts SQL decimal strings', () {
    final quote = OrderQuote.fromJson({
      'subtotal': '100.50',
      'discount': '10.25',
      'discountedSubtotal': '90.25',
      'deliveryFee': '15.00',
      'total': '105.25',
    });
    expect(quote.total, 105.25);
  });

  test('order quote rejects missing or invalid prices', () {
    final data = {
      'subtotal': 100,
      'discount': 0,
      'discountedSubtotal': 100,
      'deliveryFee': 15,
      'total': 115,
    };
    expect(
      () => OrderQuote.fromJson({...data}..remove('total')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => OrderQuote.fromJson({...data, 'total': 'NaN'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('delivery quote rejects a missing fee', () {
    expect(
      () => DeliveryQuote.fromJson({'price': '120', 'matched': false}),
      throwsA(isA<FormatException>()),
    );
  });
}
