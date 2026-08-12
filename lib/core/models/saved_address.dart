import 'delivery_address.dart';
import 'package:latlong2/latlong.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.isActive,
  });

  final String id;
  final String? label;
  final DeliveryAddress address;
  final bool isActive;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json['id'].toString(),
    label: json['label'] as String?,
    isActive: json['isActive'] as bool? ?? false,
    address: DeliveryAddress(
      district: json['address'] as String? ?? '',
      house: '',
      entrance: json['entrance'] as String?,
      floor: json['floor'] as String?,
      apartment: json['apartment'] as String?,
      point: LatLng(_toDouble(json['latitude']), _toDouble(json['longitude'])),
    ),
  );

  // The server serialises this column as a decimal string, not a JSON
  // number — unlike every other lat/lng field in the API, which sends a
  // plain number. Accepting either keeps this working if that's ever
  // fixed server-side without needing a matching client change.
  static double _toDouble(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.parse(s),
    _ => throw FormatException(
      'Expected a number or numeric string, got $value',
    ),
  };
}
