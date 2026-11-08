import '../../core/constants/app_config.dart';
import '../../core/models/order_quote.dart';

/// The amount shown at checkout, including the address quote when no
/// district-specific order quote is available yet.
class CheckoutPricing {
  const CheckoutPricing({
    required this.deliveryFee,
    required this.deliveryIsQuoted,
    required this.total,
  });

  final double deliveryFee;
  final bool deliveryIsQuoted;
  final double total;

  factory CheckoutPricing.calculate({
    required double subtotal,
    required OrderQuote? quote,
    required double? addressDeliveryFee,
    required int? etrapId,
  }) {
    final deliveryFee = etrapId != null
        ? (quote?.deliveryFee ?? AppConfig.fallbackDeliveryFee)
        : (addressDeliveryFee ?? AppConfig.fallbackDeliveryFee);
    return CheckoutPricing(
      deliveryFee: deliveryFee,
      deliveryIsQuoted: etrapId != null && quote != null && !quote.isEstimate,
      total: quote == null
          ? subtotal + deliveryFee
          : quote.total - quote.deliveryFee + deliveryFee,
    );
  }
}
