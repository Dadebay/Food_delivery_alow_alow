import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';

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

/// Turns a list of stops into a drivable line.
///
/// The courier never leaves the app for navigation (slide 8: "маршрут внутри
/// приложения"), so this runs against our own routing endpoint and the geometry
/// is drawn on our own tiles.
class RoutingService {
  RoutingService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Route through [stops] in the given order. The first entry is the courier's
  /// current position, the rest are delivery points.
  Future<RouteResult> route(List<LatLng> stops) async {
    if (stops.length < 2) return RouteResult.empty;

    final coordinates = stops
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final url =
        '${AppConfig.osrmBaseUrl}/route/v1/driving/$coordinates'
        '?overview=full&geometries=geojson';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.statusCode != 200) return _straightLine(stops);

      final routes = response.data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return _straightLine(stops);

      final route = routes.first as Map<String, dynamic>;
      final coords = (route['geometry']['coordinates'] as List<dynamic>)
          .cast<List<dynamic>>();

      return RouteResult(
        // GeoJSON is [lng, lat]; LatLng is the other way round.
        points: coords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList(),
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (error) {
      dev.log(
        'route failed, drawing straight line: $error',
        name: 'RoutingService',
      );
      return _straightLine(stops);
    }
  }

  /// No routing server / no signal: still show the courier where the stop is by
  /// connecting the points directly, with the straight-line distance.
  RouteResult _straightLine(List<LatLng> stops) {
    var meters = 0.0;
    for (var i = 0; i < stops.length - 1; i++) {
      meters += const Distance().as(LengthUnit.Meter, stops[i], stops[i + 1]);
    }
    return RouteResult(
      points: stops,
      distanceMeters: meters,
      // Rough city average of 25 km/h so the ETA is not blank.
      durationSeconds: meters / 1000 / 25 * 3600,
    );
  }
}
