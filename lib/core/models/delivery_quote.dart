import '../constants/app_config.dart';

/// The authoritative delivery price for one map point and order subtotal —
/// mirrors `POST /delivery/quote`, which reads the same per-etrap price
/// table admins edit under "Настройки доставки" (with a fallback rate for
/// addresses outside every configured etrap). The backend always recomputes
/// this again at order-creation time; this is only what the app shows the
/// customer before they place the order.
class DeliveryQuote {
  const DeliveryQuote({
    required this.fee,
    required this.price,
    this.freeDeliveryThreshold,
    this.etrapId,
    this.etrapNameRu,
    this.etrapNameTk,
    required this.matched,
    this.isFallback = false,
  });

  /// The estimate used when the backend said nothing at all — see
  /// [AppConfig.fallbackDeliveryFee].
  ///
  /// [etrapId] stays null by construction: sending an invented district id
  /// with the order would make the server charge for a district it was never
  /// told to check, which is worse than letting it resolve the point itself.
  factory DeliveryQuote.fallback({required double subtotal}) {
    const fee = AppConfig.fallbackDeliveryFee;
    return DeliveryQuote(
      fee: fee,
      price: subtotal + fee,
      matched: false,
      isFallback: true,
    );
  }

  final double fee;
  final double price;
  final double? freeDeliveryThreshold;

  /// Sent back as `deliveryEtrapId` when placing the order, so the server
  /// charges the exact fee just shown instead of re-guessing from the raw
  /// coordinates a second time.
  final int? etrapId;
  final String? etrapNameRu;
  final String? etrapNameTk;

  /// False when the point fell outside every configured etrap — [fee] is
  /// then the backend's own fallback rate, not a district-specific one.
  final bool matched;

  /// True when the backend never answered and [fee] is this app's estimate.
  /// Distinct from [matched]: an unmatched quote is still the server's
  /// number, this one is not the server's at all.
  final bool isFallback;

  String? etrapName(String languageCode) =>
      languageCode == 'tk' ? etrapNameTk : etrapNameRu;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    final etrap = json['etrap'] as Map<String, dynamic>?;
    return DeliveryQuote(
      fee: (json['fee'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      freeDeliveryThreshold: (json['freeDeliveryThreshold'] as num?)
          ?.toDouble(),
      // The district arrives nested under `etrap`, but a flat `etrapId`
      // alongside it is read too: missing the id is not cosmetic — checkout
      // sends it back with the order, and without it the server prices
      // delivery with no district at all.
      etrapId: etrap?['id'] as int? ?? json['etrapId'] as int?,
      etrapNameRu: etrap?['nameRu'] as String? ?? json['etrapNameRu'] as String?,
      etrapNameTk: etrap?['nameTk'] as String? ?? json['etrapNameTk'] as String?,
      matched: json['matched'] as bool? ?? false,
    );
  }
}
