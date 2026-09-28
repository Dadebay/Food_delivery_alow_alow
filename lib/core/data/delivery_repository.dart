import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../models/delivery_config.dart';
import '../network/api_client.dart';
import 'feature_availability.dart';

/// Which delivery tariff the administrator has switched on, and what it
/// costs to a given point under it.
///
/// Deliberately separate from [AddressRepository], which owns the older
/// `POST /delivery/quote` used by the district tariff. That endpoint is
/// still the one in use when distance pricing is off, and mixing the two
/// would blur which of them priced a given order.
class DeliveryRepository {
  DeliveryRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// The active pricing mode. Falls back to [DeliveryConfig.areaPricing] on
  /// anything short of a clean answer: district pricing is what the app has
  /// always done, so it is the safe assumption when the server cannot say.
  Future<DeliveryConfig> config() async {
    if (AppConfig.useMockData) return DeliveryConfig.areaPricing;
    try {
      final response = await _api
          .get(ApiPaths.deliveryConfig)
          .timeout(AppConfig.deliveryQuoteTimeout);
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) return DeliveryConfig.areaPricing;
      final data = response.data;
      if (data is! Map<String, dynamic>) return DeliveryConfig.areaPricing;
      return DeliveryConfig.fromJson(data);
    } catch (_) {
      return DeliveryConfig.areaPricing;
    }
  }

  /// The price to [point] for a cart worth [subtotal].
  ///
  /// The server picks the nearest branch, measures the distance, applies the
  /// day or night rate, the minimum fare and its own rounding. None of that
  /// is repeated here — the handoff is explicit that the client must not
  /// compute 16 → 15 or 17 → 20 itself.
  ///
  /// `null` means no price was obtained; the caller keeps whatever it was
  /// showing rather than inventing one.
  Future<TariffQuote?> tariffQuote({
    required LatLng point,
    required double subtotal,
    int? deliveryEtrapId,
  }) async {
    if (AppConfig.useMockData) {
      _log('skipped: app is built with USE_MOCK_DATA');
      return null;
    }
    try {
      final response = await _api
          .post(
            ApiPaths.deliveryTariffQuote,
            data: {
              'subtotal': subtotal,
              'latitude': point.latitude,
              'longitude': point.longitude,
              // Only meaningful in district mode; harmless and ignored in
              // distance mode, and omitted entirely when there is none.
              'deliveryEtrapId': ?deliveryEtrapId,
            },
          )
          .timeout(AppConfig.deliveryQuoteTimeout);
      final code = response.statusCode ?? 0;
      if (isFeatureAbsent(code)) {
        _log('HTTP $code — this server has no tariff-quote endpoint');
        return null;
      }
      if (code < 200 || code >= 300) {
        _log('HTTP $code — ${response.data}');
        return null;
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _log('HTTP $code but the body is ${data.runtimeType}, not an object');
        return null;
      }
      return TariffQuote.fromJson(data);
    } catch (error) {
      // Timeouts, DNS failures, TLS refusals and a malformed body all ended
      // here as an identical silent `null`, which is why a log saying only
      // "mock mode, network error, or non-2xx" was the whole diagnosis. The
      // caller still falls back to the estimate — but now the reason is on
      // the record.
      _log('request failed: $error');
      return null;
    }
  }

  static void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('\x1B[97;41m TARIFF \x1B[0m \x1B[1;31m$message\x1B[0m');
  }
}
