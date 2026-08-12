import 'package:latlong2/latlong.dart';

/// Ashgabat runs on microdistricts, not street names — the same address shape
/// the courier app uses, so a point the customer drops on the map lines up
/// exactly with what the courier sees.
class DeliveryAddress {
  const DeliveryAddress({
    required this.district,
    required this.house,
    this.entrance,
    this.floor,
    this.apartment,
    this.note,
    required this.point,
  });

  final String district;
  final String house;
  final String? entrance;
  final String? floor;
  final String? apartment;

  /// Free text — "домофон не работает, позвоните".
  final String? note;

  final LatLng point;

  DeliveryAddress copyWith({
    String? district,
    String? house,
    String? entrance,
    String? floor,
    String? apartment,
    String? note,
    LatLng? point,
  }) => DeliveryAddress(
    district: district ?? this.district,
    house: house ?? this.house,
    entrance: entrance ?? this.entrance,
    floor: floor ?? this.floor,
    apartment: apartment ?? this.apartment,
    note: note ?? this.note,
    point: point ?? this.point,
  );

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        district: json['district'] as String? ?? '',
        house: json['house']?.toString() ?? '',
        entrance: json['entrance']?.toString(),
        floor: json['floor']?.toString(),
        apartment: json['apartment']?.toString(),
        note: json['note'] as String?,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'district': district,
    'house': house,
    'entrance': entrance,
    'floor': floor,
    'apartment': apartment,
    'note': note,
    'lat': point.latitude,
    'lng': point.longitude,
  };

  /// "Мкр. Parahat 7, дом 12" — checkout card headline. The picker now
  /// collects the whole address as one free-text line, so `house` is empty
  /// for anything saved since — omitted rather than shown as a bare label.
  String fullLine({
    required String districtLabel,
    required String houseLabel,
  }) => house.isEmpty
      ? '$districtLabel $district'
      : '$districtLabel $district, $houseLabel $house';

  /// "подъезд 3 · этаж 5 · кв. 24" — the second line, only the parts present.
  String detailLine({
    required String entranceLabel,
    required String floorLabel,
    required String apartmentLabel,
  }) {
    final parts = <String>[];
    if (entrance != null && entrance!.isNotEmpty) {
      parts.add('$entranceLabel $entrance');
    }
    if (floor != null && floor!.isNotEmpty) {
      parts.add('$floorLabel $floor');
    }
    if (apartment != null && apartment!.isNotEmpty) {
      parts.add('$apartmentLabel $apartment');
    }
    return parts.join(' · ');
  }

  /// "Parahat 7 · д. 12" — short form for list rows.
  String shortLine(String houseLabel) =>
      house.isEmpty ? district : '$district · $houseLabel $house';
}
