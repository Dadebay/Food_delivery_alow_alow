import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;

import '../constants/app_config.dart';

/// Wraps the platform GPS for the one place the customer app needs it:
/// centring the map and offering "use my location" when picking a delivery
/// point. Unlike the courier app, nothing here streams continuously or runs
/// in the background — the customer's own position is never sent anywhere.
class LocationService extends ChangeNotifier {
  final loc.Location _location = loc.Location();

  LatLng? _current;
  String? _error;

  LatLng? get current => _current;
  String? get error => _error;

  /// Fetches a single fix, asking for permission first if needed.
  Future<LatLng?> fetch() async {
    try {
      var serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _fail('location_service_off');
          return null;
        }
      }

      var permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      final granted =
          permission == loc.PermissionStatus.granted ||
          permission == loc.PermissionStatus.grantedLimited;
      if (!granted) {
        _fail('location_permission_denied');
        return null;
      }

      final data = await _location.getLocation();
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) return null;

      _current = LatLng(lat, lng);
      _error = null;
      notifyListeners();
      return _current;
    } catch (error) {
      _fail('$error');
      return null;
    }
  }

  void _fail(String reason) {
    _error = reason;
    dev.log(reason, name: 'LocationService');
    notifyListeners();
  }

  static double kmBetween(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Kilometer, a, b);

  /// Ashgabat centre — where the map sits until a fix (or a saved address)
  /// gives it something better.
  static const LatLng fallbackCenter = LatLng(
    AppConfig.defaultLat,
    AppConfig.defaultLng,
  );
}
