/// Central place for every server address and tuning constant.
///
/// Same approach as the courier app: one file changes when this is installed
/// on the customer's own server.
class AppConfig {
  const AppConfig._();

  // ─── Backend ─────────────────────────────────────────────────
  /// Production API. Override this for a local or staging server, for example:
  /// `--dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1/`.
  static const String _defaultApiBaseUrl = 'https://a7-tagam.com.tm/api/v1/';

  /// Same server reached by raw IP, used only when the address above cannot
  /// be reached at all — `ApiClient` retries such a request here and then
  /// keeps using it for the rest of the session.
  ///
  /// HTTPS, like the address above: every request the app makes, including
  /// the OTP login and the order it places, goes over TLS on this path too.
  ///
  /// The certificate is issued for the domain name and cannot match a bare
  /// IP — `ApiClient` accepts that one mismatch, for this host alone.
  ///
  /// Leave empty to disable the fallback; override with
  /// `--dart-define=API_FALLBACK_URL=https://1.2.3.4/api/v1/`.
  static const String _defaultApiFallbackUrl = 'https://216.250.12.132/api/v1/';

  static String get apiBaseUrl => apiBaseUrls.first;

  /// Every address the API can be reached at, best first. `ApiClient` walks
  /// this list on a connection failure.
  static List<String> get apiBaseUrls {
    const configured = String.fromEnvironment('API_BASE_URL');
    const configuredFallback = String.fromEnvironment('API_FALLBACK_URL');
    final urls = <String>[];
    void add(String value) {
      if (value.isEmpty) return;
      final normalized = value.endsWith('/') ? value : '$value/';
      if (!urls.contains(normalized)) urls.add(normalized);
    }

    add(configured.isNotEmpty ? configured : _defaultApiBaseUrl);
    add(configuredFallback.isNotEmpty ? configuredFallback : _defaultApiFallbackUrl);
    return urls;
  }

  /// Demo mode: the app runs entirely on the bundled mock catalogue and mock
  /// order flow (see `core/data/mock/mock_data.dart`), so the whole ordering
  /// experience can be shown and tested before the backend exists.
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  // ─── Map ─────────────────────────────────────────────────────
  /// Same tile server as the courier app.
  static const String mapTileUrl = 'https://a7-tagam.com.tm/tile/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.gurbanov.alowalow';

  /// Ashgabat — map opens here before the customer places a pin.
  static const double defaultLat = 37.9601;
  static const double defaultLng = 58.3261;
  static const double defaultZoom = 14.0;
  static const double pickZoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;

  static const Duration tileCacheMaxStale = Duration(days: 30);

  /// How long a cached GET response (menu, order history, ...) stays
  /// eligible to answer a request once the network call itself fails — see
  /// `ApiClient`. Menu and order history are worth seeing well after the
  /// last successful sync, so this is generous rather than tuned tight.
  static const Duration apiCacheMaxStale = Duration(days: 7);

  /// Refresh the customer map shortly after each courier GPS upload.
  static const Duration trackingPollInterval = Duration(seconds: 15);

  // ─── Misc ────────────────────────────────────────────────────
  static const String currency = 'TMT';

  /// How long checkout waits for the backend's per-district delivery price
  /// before giving up and showing [fallbackDeliveryFee]. Generous on purpose:
  /// a real answer a few seconds late still beats an invented one.
  static const Duration deliveryQuoteTimeout = Duration(seconds: 30);

  /// Shown when `POST /delivery/quote` gives nothing at all — no network, a
  /// timeout, or a non-2xx reply.
  ///
  /// This is an estimate, not a promise: the backend recomputes the fee when
  /// the order is actually created, so a customer who checks out on this
  /// number can be charged a different one. The UI marks it as approximate
  /// for exactly that reason. When the backend grows a default-fee field of
  /// its own, read it here instead of this constant.
  static const double fallbackDeliveryFee = 20;

  /// Mirrors the server-side cash-on-delivery rule.
  static const double deliveryFee = 15;
  static const double freeDeliveryThreshold = 150;

  static double deliveryFeeFor(double subtotal) => subtotal >= freeDeliveryThreshold ? 0 : deliveryFee;
  static const String supportPhone = '+99312000000';

  /// Used to build the Play Store link when the backend has not sent one.
  /// Must match `applicationId` in `android/app/build.gradle.kts`.
  static const String androidPackageName = 'com.gurbanov.alowalow';
}
