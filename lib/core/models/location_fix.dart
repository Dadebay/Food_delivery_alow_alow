import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

/// A single platform measurement, carrying the moment the receiver actually
/// took it rather than the moment the app noticed. Ported from the courier
/// app, where the same validation stopped NaN and future-dated readings from
/// reaching the map.
class LocationFix {
  const LocationFix({
    required this.point,
    required this.recordedAt,
    this.accuracy,
    this.heading,
    this.speed,
  });

  static const freshness = Duration(minutes: 1);
  final LatLng point;
  final DateTime recordedAt;
  final double? accuracy;
  final double? heading;
  final double? speed;

  bool isFresh(DateTime now) {
    final age = now.difference(recordedAt);
    return !age.isNegative && age <= freshness;
  }

  /// How far ahead of [now] a measurement may claim to be and still be
  /// believed. Phone and app clocks are the same clock here, but a reading can
  /// be stamped a moment after it is read; beyond this the timestamp is wrong
  /// rather than merely fresh.
  static const clockSkew = Duration(minutes: 1);

  /// Builds a fix from a platform reading, or null when the reading cannot be
  /// trusted.
  ///
  /// A missing `time` is **not** a reason to reject. `LocationData.time` is
  /// nullable in the package's own contract, and a coarse network fix with
  /// finite coordinates is exactly the reading this app wants indoors —
  /// throwing it away for a missing timestamp would discard the fallback the
  /// whole tiered lookup exists to reach. Such a reading is stamped [now]:
  /// it arrived now, and treating it as older would only age it out early.
  ///
  /// Coordinates outside their ranges, NaN, infinity, an impossible accuracy
  /// radius and a timestamp clearly in the past-as-zero or the future are all
  /// still rejected.
  static LocationFix? fromData(LocationData data, DateTime now) {
    final lat = data.latitude;
    final lng = data.longitude;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }

    final time = data.time;
    final DateTime recordedAt;
    if (time == null) {
      recordedAt = now;
    } else {
      if (!time.isFinite ||
          time <= 0 ||
          time > now.add(clockSkew).millisecondsSinceEpoch) {
        return null;
      }
      recordedAt = DateTime.fromMillisecondsSinceEpoch(
        time.toInt(),
        isUtc: true,
      );
    }

    final accuracy = data.accuracy;
    if (accuracy != null && bounded(accuracy, 5000) == null) return null;
    return LocationFix(
      point: LatLng(lat, lng),
      recordedAt: recordedAt,
      accuracy: accuracy,
      heading: bounded(data.heading, 360),
      speed: bounded(data.speed, 100),
    );
  }

  static double? bounded(double? value, double max) =>
      value != null && value.isFinite && value >= 0 && value <= max
      ? value
      : null;

  Map<String, dynamic> toJson() => {
    'latitude': point.latitude,
    'longitude': point.longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (heading != null) 'heading': heading,
    if (speed != null) 'speed': speed,
  };
}
