import 'package:latlong2/latlong.dart';

import '../network/api_client.dart';

/// Turns a dropped map pin into a starting guess at a district/street name.
///
/// Goes through our own backend rather than calling Nominatim/Photon
/// straight from the device — the same reason road routing goes through the
/// backend instead of hitting OSRM directly (see the courier route
/// endpoint): mobile networks in some of the app's markets block the public
/// OSM hosts outright, while the backend's own network path is unrestricted.
class GeocodingService {
  GeocodingService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// A short, human line for the point — "Parahat 7, Görogly köçesi" style —
  /// or `null` on any failure (no network, no match, bad response shape).
  /// Callers treat that exactly like the customer never having typed
  /// anything: the field stays editable, nothing is ever forced on them.
  Future<String?> reverseGeocode(LatLng point) async {
    try {
      final response = await _api.get(
        ApiPaths.geocodingReverse,
        query: {'lat': point.latitude, 'lon': point.longitude},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final line = data['line'];
      return line is String && line.isNotEmpty ? line : null;
    } catch (_) {
      return null;
    }
  }
}
