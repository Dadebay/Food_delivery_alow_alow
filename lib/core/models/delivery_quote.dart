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
  });

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
  /// then the fallback rate, not a district-specific one.
  final bool matched;

  String? etrapName(String languageCode) =>
      languageCode == 'tk' ? etrapNameTk : etrapNameRu;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    final etrap = json['etrap'] as Map<String, dynamic>?;
    return DeliveryQuote(
      fee: (json['fee'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      freeDeliveryThreshold: (json['freeDeliveryThreshold'] as num?)
          ?.toDouble(),
      etrapId: etrap?['id'] as int?,
      etrapNameRu: etrap?['nameRu'] as String?,
      etrapNameTk: etrap?['nameTk'] as String?,
      matched: json['matched'] as bool? ?? false,
    );
  }
}
