import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/location_fix.dart';
import 'package:food_delivery/core/services/location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the platform channel so the tests can decide exactly what
/// the receiver does — answer, stay silent, or answer only once the accuracy
/// setting drops to the network tier.
class _FakeLocation implements loc.Location {
  _FakeLocation({
    this.permission = loc.PermissionStatus.granted,
    this.serviceOn = true,
    this.oneShot,
    this.oneShotWhenBalanced,
  });

  final loc.PermissionStatus permission;
  final bool serviceOn;

  /// Answered immediately by every `getLocation()` call.
  final loc.LocationData? oneShot;

  /// Answered only after [LocationAccuracy.balanced] has been requested —
  /// the indoor case, where satellites never produce anything and the
  /// Wi-Fi/cell tier does.
  final loc.LocationData? oneShotWhenBalanced;

  final _stream = StreamController<loc.LocationData>.broadcast();

  /// Every accuracy the service asked for, in order. The tiering is the point
  /// of this service, so the test asserts on the sequence rather than trusting
  /// that a reading happened to arrive.
  final List<loc.LocationAccuracy> requestedAccuracies = [];

  int getLocationCalls = 0;

  void emit(loc.LocationData data) => _stream.add(data);

  @override
  Future<bool> serviceEnabled() async => serviceOn;

  @override
  Future<bool> requestService() async => serviceOn;

  @override
  Future<loc.PermissionStatus> hasPermission() async => permission;

  @override
  Future<loc.PermissionStatus> requestPermission() async => permission;

  @override
  Future<bool> changeSettings({
    loc.LocationAccuracy? accuracy = loc.LocationAccuracy.high,
    int? interval = 1000,
    double? distanceFilter = 0,
    bool? pausesLocationUpdatesAutomatically = true,
  }) async {
    if (accuracy != null) requestedAccuracies.add(accuracy);
    return true;
  }

  @override
  Stream<loc.LocationData> get onLocationChanged => _stream.stream;

  @override
  Future<loc.LocationData> getLocation() async {
    getLocationCalls++;
    final data = oneShot;
    if (data != null) return data;

    final balanced = oneShotWhenBalanced;
    if (balanced != null &&
        requestedAccuracies.contains(loc.LocationAccuracy.balanced)) {
      return balanced;
    }
    // Indoors the platform simply never answers; a future that never
    // completes is exactly the failure this service had to survive.
    return Completer<loc.LocationData>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

loc.LocationData _data(
  double lat,
  double lng,
  DateTime? at, {
  double? accuracy = 12.0,
}) => loc.LocationData.fromMap({
  'latitude': lat,
  'longitude': lng,
  'time': ?at?.millisecondsSinceEpoch.toDouble(),
  'accuracy': ?accuracy,
});

String _cached(LatLng point, DateTime at) =>
    '{"latitude":${point.latitude},"longitude":${point.longitude},'
    '"recordedAt":"${at.toIso8601String()}"}';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  /// Small enough that a test finishing late is a real regression, large
  /// enough not to flake on a loaded machine.
  const budget = Duration(milliseconds: 200);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SharedPreferences> prefsWith(String? cache) async {
    SharedPreferences.setMockInitialValues(
      cache == null ? {} : {'location.lastFix': cache},
    );
    return SharedPreferences.getInstance();
  }

  group('live acquisition', () {
    test('returns the one-shot reading when the receiver answers', () async {
      final service = LocationService(
        platform: _FakeLocation(oneShot: _data(37.95, 58.32, now)),
        now: () => now,
      );

      expect(await service.fetch(), LatLng(37.95, 58.32));
      expect(service.error, isNull);
      expect(service.lastSource, LocationSource.live);
    });

    test(
      'a stream fix satisfies the request when the one-shot never does',
      () async {
        final platform = _FakeLocation();
        final service = LocationService(
          platform: platform,
          now: () => now,
          fixTimeout: const Duration(seconds: 2),
        );

        final pending = service.fetch();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        platform.emit(_data(37.96, 58.33, now));

        expect(await pending, LatLng(37.96, 58.33));
        expect(service.lastSource, LocationSource.live);
      },
    );

    test('drops to the network tier when satellites produce nothing', () async {
      // The indoor case: high accuracy answers never, balanced answers at
      // once. Asserting on the recorded order proves the downgrade happened
      // rather than inferring it from a reading that arrived anyway.
      final platform = _FakeLocation(
        oneShotWhenBalanced: _data(37.97, 58.34, now, accuracy: 850),
      );
      final service = LocationService(
        platform: platform,
        now: () => now,
        fixTimeout: budget,
        preciseAttempt: const Duration(milliseconds: 40),
      );

      expect(await service.fetch(), LatLng(37.97, 58.34));
      expect(
        platform.requestedAccuracies,
        [loc.LocationAccuracy.high, loc.LocationAccuracy.balanced],
        reason: 'precise must be tried first, then the Wi-Fi/cell tier',
      );
      expect(platform.getLocationCalls, 2);
    });
  });

  group('stale platform readings', () {
    test('a hours-old platform reading is never returned as live', () async {
      // The platform can hand back its own last-known position, recorded long
      // before this lookup. Returning that as "you are here" puts the pin
      // where the customer used to be — with a tight accuracy radius, so
      // nothing warns them — and that point becomes a delivery address.
      final service = LocationService(
        platform: _FakeLocation(
          oneShot: _data(
            37.10,
            58.10,
            now.subtract(const Duration(hours: 4)),
            accuracy: 5,
          ),
        ),
        now: () => now,
        fixTimeout: budget,
      );

      expect(await service.fetch(), isNull, reason: 'too old to be live');
      expect(service.lastSource, LocationSource.none);
      expect(service.error, 'location_no_fix');
    });

    test('an older-but-recent reading comes back flagged approximate', () async {
      // Five minutes old: past `isFresh`, inside `maxCacheAge`. Worth using as
      // a starting view, never worth presenting as the current spot.
      final service = LocationService(
        platform: _FakeLocation(
          oneShot: _data(
            37.20,
            58.20,
            now.subtract(const Duration(minutes: 5)),
            accuracy: 5,
          ),
        ),
        now: () => now,
        fixTimeout: budget,
      );

      expect(await service.fetch(), LatLng(37.20, 58.20));
      expect(service.lastSource, LocationSource.cached);
      expect(
        service.lastResultIsApproximate,
        isTrue,
        reason: 'a tight radius must not make an old point look current',
      );
    });

    test(
      'a reading older than the one held never overwrites the answer',
      () async {
        // Cache holds a point from one minute ago; the platform then offers an
        // hour-old one. The old reading must not become the returned position
        // while the getters still describe the newer one.
        final prefs = await prefsWith(
          _cached(
            LatLng(37.94, 58.31),
            now.subtract(const Duration(minutes: 1)),
          ),
        );
        final service = LocationService(
          prefs: prefs,
          platform: _FakeLocation(
            oneShot: _data(
              37.10,
              58.10,
              now.subtract(const Duration(hours: 1)),
              accuracy: 5,
            ),
          ),
          now: () => now,
          fixTimeout: budget,
        );

        expect(await service.fetch(), LatLng(37.94, 58.31));
        expect(service.current, LatLng(37.94, 58.31));
        expect(service.lastSource, LocationSource.cached);
      },
    );
  });

  group('timeout budget', () {
    test(
      'the whole lookup is bounded by fixTimeout, not by the precise phase',
      () async {
        // The regression this guards: the precise phase used to be waited out
        // in full whatever the total budget was, so a 200 ms timeout took the
        // six seconds of `defaultPreciseAttempt`.
        final service = LocationService(
          platform: _FakeLocation(),
          now: () => now,
          fixTimeout: budget,
        );

        final elapsed = Stopwatch()..start();
        expect(await service.fetch(), isNull);
        elapsed.stop();

        expect(service.error, 'location_no_fix');
        expect(service.lastSource, LocationSource.none);
        expect(
          elapsed.elapsed,
          lessThan(budget * 3),
          reason: 'took ${elapsed.elapsed}, budget was $budget',
        );
      },
    );

    test('a precise phase longer than the budget cannot outlast it', () async {
      final service = LocationService(
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
        preciseAttempt: const Duration(seconds: 6),
      );

      expect(service.preciseAttempt, budget, reason: 'clamped on construction');

      final elapsed = Stopwatch()..start();
      await service.fetch();
      elapsed.stop();

      expect(elapsed.elapsed, lessThan(budget * 3));
    });
  });

  group('cache', () {
    test('falls back to a recent remembered position', () async {
      final prefs = await prefsWith(
        _cached(LatLng(37.94, 58.31), now.subtract(const Duration(minutes: 3))),
      );
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      expect(await service.fetch(), LatLng(37.94, 58.31));
      expect(service.error, 'location_stale');
      expect(service.lastSource, LocationSource.cached);
    });

    test('a cached point is always presented as approximate', () async {
      // Even a cache entry recorded at metre accuracy describes where the
      // customer was, not where they are — the pin still needs verifying.
      final prefs = await prefsWith(
        _cached(LatLng(37.94, 58.31), now.subtract(const Duration(minutes: 3))),
      );
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      await service.fetch();
      expect(service.currentIsApproximate, isFalse, reason: 'radius is fine');
      expect(service.lastResultIsApproximate, isTrue, reason: 'but it is old');
    });

    test('a coarse live fix is flagged approximate', () async {
      final service = LocationService(
        platform: _FakeLocation(
          oneShot: _data(37.95, 58.32, now, accuracy: 900),
        ),
        now: () => now,
      );

      await service.fetch();
      expect(service.lastSource, LocationSource.live);
      expect(service.lastResultIsApproximate, isTrue);
    });

    test('a day-old position is not offered as the current one', () async {
      final prefs = await prefsWith(
        _cached(LatLng(37.94, 58.31), now.subtract(const Duration(days: 1))),
      );
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      expect(await service.fetch(), isNull);
      expect(service.current, isNotNull, reason: 'still available to the map');
      expect(service.isStale, isTrue);
      expect(service.lastSource, LocationSource.none);
    });

    test('a corrupt cache entry is simply no cache', () async {
      final prefs = await prefsWith('{not json at all');
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      expect(service.current, isNull);
      expect(await service.fetch(), isNull);
      expect(service.error, 'location_no_fix');
    });

    test('a future-dated cache entry is rejected', () async {
      final prefs = await prefsWith(
        _cached(LatLng(37.94, 58.31), now.add(const Duration(hours: 2))),
      );
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      expect(service.current, isNull);
      expect(await service.fetch(), isNull);
    });
  });

  group('permission and service', () {
    test('a refusal is never papered over with a cached point', () async {
      final prefs = await prefsWith(_cached(LatLng(37.94, 58.31), now));
      final service = LocationService(
        prefs: prefs,
        platform: _FakeLocation(permission: loc.PermissionStatus.denied),
        now: () => now,
      );

      expect(await service.fetch(), isNull);
      expect(service.error, 'location_permission_denied');
      expect(service.isBlocked, isTrue);
      expect(service.lastSource, LocationSource.none);
    });

    test('location switched off is reported as its own cause', () async {
      final service = LocationService(
        platform: _FakeLocation(serviceOn: false),
        now: () => now,
      );

      expect(await service.fetch(), isNull);
      expect(service.error, 'location_service_off');
      expect(service.isBlocked, isTrue);
    });

    test('no fix with permission granted is not reported as blocked', () async {
      // The distinction the two map widgets rely on: this customer must be
      // asked to drop a pin, not sent to the settings app.
      final service = LocationService(
        platform: _FakeLocation(),
        now: () => now,
        fixTimeout: budget,
      );

      await service.fetch();
      expect(service.error, 'location_no_fix');
      expect(service.isBlocked, isFalse);
    });

    test('iOS reduced-accuracy permission is accepted', () async {
      // `grantedLimited` is iOS 14+ only — the platform interface documents it
      // as such, and the Android plugin never returns it (it maps its result
      // to 0/1/2, granted/denied/deniedForever, from a check on
      // ACCESS_FINE_LOCATION alone).
      //
      // So this covers the iOS "Precise: Off" case and nothing else. Android's
      // approximate-location choice does NOT arrive here; see
      // INDOOR_LOCATION_TASK.md and the note left with this change.
      final service = LocationService(
        platform: _FakeLocation(
          permission: loc.PermissionStatus.grantedLimited,
          oneShot: _data(37.95, 58.32, now, accuracy: 1200),
        ),
        now: () => now,
      );

      expect(await service.fetch(), LatLng(37.95, 58.32));
      expect(service.lastResultIsApproximate, isTrue);
    });
  });

  group('concurrency', () {
    test('concurrent calls share one acquisition', () async {
      final platform = _FakeLocation(oneShot: _data(37.95, 58.32, now));
      final service = LocationService(platform: platform, now: () => now);

      final results = await Future.wait([
        service.fetch(),
        service.fetch(),
        service.fetch(),
      ]);

      expect(results, everyElement(LatLng(37.95, 58.32)));
      expect(
        platform.getLocationCalls,
        1,
        reason: 'three taps must not become three platform lookups',
      );
    });

    test('a second fetch works after the first has failed', () async {
      final platform = _FakeLocation();
      final service = LocationService(
        platform: platform,
        now: () => now,
        fixTimeout: budget,
      );

      expect(await service.fetch(), isNull);
      platform.requestedAccuracies.clear();

      final pending = service.fetch();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      platform.emit(_data(37.99, 58.36, now));

      expect(await pending, LatLng(37.99, 58.36));
      expect(service.error, isNull);
      expect(platform.requestedAccuracies.first, loc.LocationAccuracy.high);
    });
  });

  group('LocationFix validation', () {
    test('a valid reading without a timestamp is stamped now', () async {
      // `LocationData.time` is nullable by contract. Indoors a coarse network
      // reading is exactly what this app is reaching for, and discarding it
      // over a missing timestamp would throw away the fallback.
      final fix = LocationFix.fromData(_data(37.95, 58.32, null), now);

      expect(fix, isNotNull);
      expect(fix!.recordedAt, now);
      expect(fix.point, LatLng(37.95, 58.32));
    });

    test('a timeless reading still reaches the caller', () async {
      final service = LocationService(
        platform: _FakeLocation(oneShot: _data(37.95, 58.32, null)),
        now: () => now,
      );

      expect(await service.fetch(), LatLng(37.95, 58.32));
    });

    test('impossible coordinates are rejected', () {
      expect(LocationFix.fromData(_data(91, 58.32, now), now), isNull);
      expect(LocationFix.fromData(_data(37.95, 181, now), now), isNull);
      expect(LocationFix.fromData(_data(double.nan, 58.32, now), now), isNull);
      expect(
        LocationFix.fromData(_data(37.95, double.infinity, now), now),
        isNull,
      );
    });

    test('a clearly future timestamp is rejected', () {
      expect(
        LocationFix.fromData(
          _data(37.95, 58.32, now.add(const Duration(hours: 1))),
          now,
        ),
        isNull,
      );
    });

    test('a timestamp a few seconds ahead survives clock skew', () {
      expect(
        LocationFix.fromData(
          _data(37.95, 58.32, now.add(const Duration(seconds: 5))),
          now,
        ),
        isNotNull,
      );
    });

    test('an impossible accuracy radius is rejected', () {
      expect(
        LocationFix.fromData(_data(37.95, 58.32, now, accuracy: -1), now),
        isNull,
      );
      expect(
        LocationFix.fromData(_data(37.95, 58.32, now, accuracy: 99999), now),
        isNull,
      );
    });
  });
}
