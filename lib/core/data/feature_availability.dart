/// Thrown when an endpoint answers in a way that means "this server build
/// does not have the feature", rather than "the request failed".
///
/// The loyalty, tariff and ordering-hours endpoints ship in an API release
/// that is not deployed yet (see `MOBILE_LOYALTY_DELIVERY_HANDOFF.md`), so
/// the same app has to run against a server with them and one without. A
/// 404 from `/loyalty/gifts` is not an error worth showing the customer —
/// it means this restaurant's server has no gift shop, and the whole block
/// should stay off the screen.
///
/// Distinct from a network failure on purpose: "we could not reach the
/// server" deserves a retry button, "this server has no such feature" does
/// not.
class FeatureUnavailableException implements Exception {
  const FeatureUnavailableException(this.path, this.statusCode);

  final String path;
  final int statusCode;

  @override
  String toString() =>
      'Feature at $path is not available on this server ($statusCode)';
}

/// The status codes that mean the feature is absent rather than broken.
///
/// 404 is the common case (no route). 501 is a server that knows the route
/// and says it is not implemented. Anything else — 400, 401, 409, 5xx — is a
/// real answer about this particular request and must not be swallowed.
bool isFeatureAbsent(int statusCode) =>
    statusCode == 404 || statusCode == 501;
