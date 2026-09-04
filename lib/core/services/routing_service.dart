import 'package:latlong2/latlong.dart';

/// A driving route: the line to draw plus the numbers for the header card.
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();

  static const empty = RouteResult(
    points: [],
    distanceMeters: 0,
    durationSeconds: 0,
  );

  bool get isEmpty => points.isEmpty;
}

/// Demo-mode-only stand-in for a real route.
///
/// The customer app never calls a routing provider itself — the real
/// courier-to-address line comes from the backend (see
/// `OrderRepository.courierRoute`, which proxies the same self-hosted routing
/// service the courier app uses). This class only draws a plausible-looking
/// line for [OrderProvider]'s local demo simulation, where there is no real
/// order or backend to ask.
class RoutingService {
  const RoutingService();

  /// A gently curved line through [stops] — enough for the demo courier
  /// marker to travel along something other than a single straight segment,
  /// with a straight-line distance/ETA to match.
  Future<RouteResult> route(List<LatLng> stops) async {
    if (stops.length < 2) return RouteResult.empty;

    final points = <LatLng>[];
    for (var i = 0; i < stops.length - 1; i++) {
      points.addAll(_arc(stops[i], stops[i + 1]));
    }

    var meters = 0.0;
    for (var i = 0; i < stops.length - 1; i++) {
      meters += const Distance().as(LengthUnit.Meter, stops[i], stops[i + 1]);
    }

    return RouteResult(
      points: points,
      distanceMeters: meters,
      // Rough city average of 25 km/h so the demo ETA is not blank.
      durationSeconds: meters / 1000 / 25 * 3600,
    );
  }

  /// Interpolated points with a small perpendicular bow, so the line reads
  /// as a route rather than a ruler-straight demo artifact.
  List<LatLng> _arc(LatLng from, LatLng to) {
    const steps = 12;
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    // Perpendicular to the from→to direction, scaled to a few percent of the
    // segment's own length.
    final bowLat = -dLng * 0.06;
    final bowLng = dLat * 0.06;

    return List.generate(steps + 1, (i) {
      final t = i / steps;
      // Peaks at the midpoint, zero at both ends.
      final bow = 4 * t * (1 - t);
      return LatLng(
        from.latitude + dLat * t + bowLat * bow,
        from.longitude + dLng * t + bowLng * bow,
      );
    });
  }
}
