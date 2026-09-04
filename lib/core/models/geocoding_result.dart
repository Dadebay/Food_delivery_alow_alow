import 'package:latlong2/latlong.dart';

/// One match from the backend's forward address search — a real, named place
/// from OpenStreetMap, not text the customer typed. Selecting one is what
/// lets the district field stay filled with an address that actually exists
/// on the map, the same guarantee a dropped pin already gives.
class GeocodingResult {
  const GeocodingResult({
    required this.label,
    required this.point,
    required this.aliases,
  });

  final String label;
  final LatLng point;

  /// Other names OSM has on file for the same place — a Russian and a
  /// Turkmen name for one street, for instance.
  final List<String> aliases;

  factory GeocodingResult.fromJson(Map<String, dynamic> json) =>
      GeocodingResult(
        label: json['label'] as String? ?? '',
        point: LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        aliases: (json['aliases'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}
