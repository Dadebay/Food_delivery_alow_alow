import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/order_quote.dart';
import 'package:food_delivery/modules/checkout/checkout_pricing.dart';

void main() {
  const quote = OrderQuote(
    subtotal: 100,
    discount: 10,
    discountedSubtotal: 90,
    deliveryFee: 15,
    total: 105,
  );

  test('uses the server fee and discounted total for a resolved district', () {
    final pricing = CheckoutPricing.calculate(
      subtotal: 100,
      quote: quote,
      addressDeliveryFee: 30,
      etrapId: 3,
    );
    expect(pricing.deliveryFee, 15);
    expect(pricing.deliveryIsQuoted, isTrue);
    expect(pricing.total, 105);
  });

  test(
    'replaces a zero district fee with the address quote outside the district',
    () {
      const noDistrictQuote = OrderQuote(
        subtotal: 100,
        discount: 10,
        discountedSubtotal: 90,
        deliveryFee: 0,
        total: 90,
      );
      final pricing = CheckoutPricing.calculate(
        subtotal: 100,
        quote: noDistrictQuote,
        addressDeliveryFee: 30,
        etrapId: null,
      );
      expect(pricing.deliveryFee, 30);
      expect(pricing.deliveryIsQuoted, isFalse);
      expect(pricing.total, 120);
    },
  );

  test('does not label a local fallback as a server quote', () {
    final pricing = CheckoutPricing.calculate(
      subtotal: 100,
      quote: OrderQuote.estimate(subtotal: 100),
      addressDeliveryFee: null,
      etrapId: 3,
    );
    expect(pricing.deliveryIsQuoted, isFalse);
    expect(pricing.total, 120);
  });
}
