import 'dart:io' show Platform;

/// Central place for every server address and tuning constant.
///
/// Same approach as the courier app: one file changes when this is installed
/// on the customer's own server.
class AppConfig {
  const AppConfig._();

  // ─── Backend ─────────────────────────────────────────────────
  /// The Android emulator reaches the host machine through `10.0.2.2`.
  /// Override this for an iOS simulator or a physical device, for example:
  /// `--dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1/`.
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.endsWith('/') ? configured : '$configured/';
    }
    return Platform.isAndroid
        ? 'http://10.0.2.2:4000/api/v1/'
        : 'http://127.0.0.1:4000/api/v1/';
  }

  /// Demo mode: the app runs entirely on the bundled mock catalogue and mock
  /// order flow (see `core/data/mock/mock_data.dart`), so the whole ordering
  /// experience can be shown and tested before the backend exists.
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  // ─── Map ─────────────────────────────────────────────────────
  /// Same tile server as the courier app.
  static const String mapTileUrl =
      'https://map.ayterek.com/tile/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.gurbanov.alowalow';

  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  /// Ashgabat — map opens here before the customer places a pin.
  static const double defaultLat = 37.9601;
  static const double defaultLng = 58.3261;
  static const double defaultZoom = 14.0;
  static const double pickZoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;

  static const Duration tileCacheMaxStale = Duration(days: 30);

  /// Refresh the customer map shortly after each courier GPS upload.
  static const Duration trackingPollInterval = Duration(seconds: 15);

  // ─── Misc ────────────────────────────────────────────────────
  static const String currency = 'TMT';

  /// Mirrors the server-side cash-on-delivery rule.
  static const double deliveryFee = 15;
  static const double freeDeliveryThreshold = 150;

  static double deliveryFeeFor(double subtotal) =>
      subtotal >= freeDeliveryThreshold ? 0 : deliveryFee;
  static const String supportPhone = '+99312000000';
}
