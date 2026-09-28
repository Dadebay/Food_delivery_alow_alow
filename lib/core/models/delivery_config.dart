import '../utils/json_number.dart';

/// How the administrator has chosen to price delivery for everybody —
/// `GET /delivery/config`.
///
/// This is not a switch the customer sees. The app reads it only to know
/// which request to make for a price: with coordinates when delivery is
/// charged by distance, by district otherwise. Either way the number that
/// gets charged comes from the server.
class DeliveryConfig {
  const DeliveryConfig({
    required this.distancePricingEnabled,
    this.dayRate,
    this.nightRate,
  });

  /// True = priced per kilometre from the nearest branch; false = the
  /// existing per-district (etrap) table.
  final bool distancePricingEnabled;

  /// The rates behind the mode, for a caption if a screen wants one. The app
  /// never multiplies by them: rounding, the minimum fare and the day/night
  /// boundary all live on the server.
  final double? dayRate;
  final double? nightRate;

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) => DeliveryConfig(
    distancePricingEnabled: json['distancePricingEnabled'] as bool? ?? false,
    dayRate: readDouble(json['dayRate']),
    nightRate: readDouble(json['nightRate']),
  );

  /// What the app assumes before the config lands, and on a server that has
  /// no such endpoint yet: the district pricing that has always been there.
  static const DeliveryConfig areaPricing = DeliveryConfig(
    distancePricingEnabled: false,
  );
}

/// The delivery price for one point under the active tariff — `POST
/// /delivery/tariff-quote`.
class TariffQuote {
  const TariffQuote({
    required this.fee,
    this.pricingMode,
    this.distanceMeters,
    this.tariff,
    this.validUntil,
  });

  final double fee;

  /// `AREA` or `DISTANCE` as the server names it — usable as a caption, not
  /// as something to branch pricing on.
  final String? pricingMode;

  /// Straight-line distance to the nearest branch, when priced by distance.
  final double? distanceMeters;

  /// The rate that was applied, for a caption (e.g. a night tariff).
  final double? tariff;

  /// After this instant the price must be asked for again. `null` means it
  /// does not expire on its own — a change of address or cart still does.
  final DateTime? validUntil;

  bool get isExpired =>
      validUntil != null && DateTime.now().toUtc().isAfter(validUntil!.toUtc());

  factory TariffQuote.fromJson(Map<String, dynamic> json) => TariffQuote(
    fee: readDouble(json['fee']) ?? 0,
    pricingMode: json['pricingMode'] as String?,
    distanceMeters: readDouble(json['distanceMeters']),
    tariff: readDouble(json['tariff']),
    validUntil: DateTime.tryParse(json['validUntil'] as String? ?? ''),
  );
}
