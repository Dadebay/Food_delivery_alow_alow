import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/location_fix.dart';

/// Where a point handed back by [LocationService.fetch] came from.
enum LocationSource {
  /// The receiver answered during this lookup.
  live,

  /// The receiver produced nothing and a recent remembered point stood in.
  cached,

  /// No usable point at all.
  none,
}

/// Wraps the platform GPS for the one place the customer app needs it:
/// centring the map and offering "use my location" when picking a delivery
/// point. Unlike the courier app, nothing here streams continuously or runs
/// in the background — the customer's own position is never sent anywhere.
///
/// A single `getLocation()` call used to be the whole implementation, and it
/// is exactly what fails indoors: the platform simply never answers, the
/// future hangs, and the customer is left holding a spinner. Three things fix
/// that, all borrowed from the courier app:
///
///   * a **stream alongside the one-shot read** — whichever produces a
///     reading first wins, and a fix that lands two seconds late still counts;
///   * a **hard timeout**, so the button always comes back;
///   * a **remembered last position**, so a failed lookup near the same place
///     still opens the map in the right neighbourhood instead of on the
///     city centre.
///
/// The remaining indoor case is a receiver that answers eventually but only
/// from satellites: inside a building it never sees enough of them, so the
/// high-accuracy request sits there until the timeout even though the phone
/// could have placed itself from Wi-Fi and cell towers in a second. So the
/// request is tiered — see [preciseAttempt].
class LocationService extends ChangeNotifier {
  LocationService({
    SharedPreferences? prefs,
    loc.Location? platform,
    DateTime Function()? now,
    this.fixTimeout = const Duration(seconds: 15),
    Duration preciseAttempt = defaultPreciseAttempt,
  }) : _prefs = prefs,
       _location = platform ?? loc.Location(),
       _now = now ?? DateTime.now,
       // Never longer than the whole budget: a precise phase that outlasts
       // the total timeout is the bug this used to have, and clamping here
       // means no caller can reintroduce it by passing an odd pair.
       preciseAttempt = preciseAttempt <= fixTimeout
           ? preciseAttempt
           : fixTimeout {
    _restore();
  }

  static const String _cacheKey = 'location.lastFix';

  /// How long satellites get before the request drops to a network-based
  /// one.
  ///
  /// `LocationAccuracy.high` maps to the platform's satellites-first mode,
  /// which is what stalls indoors; `balanced` places the phone from Wi-Fi and
  /// cell towers instead — hundreds of metres out at worst, but available
  /// through a roof, and the customer drags the pin from there anyway. Going
  /// precise-first rather than the other way round keeps outdoor readings as
  /// exact as before: outdoors a satellite fix lands well inside this window
  /// and the downgrade never happens.
  static const Duration defaultPreciseAttempt = Duration(seconds: 6);

  /// This instance's satellite phase, clamped to [fixTimeout].
  final Duration preciseAttempt;

  /// How old a remembered position may be and still stand in for a live one.
  /// Picking a delivery address does not need the metre the customer is
  /// standing on, but it does need the right street — and a position from
  /// yesterday is no longer evidence of that.
  static const Duration maxCacheAge = Duration(minutes: 10);

  final SharedPreferences? _prefs;
  final loc.Location _location;
  final DateTime Function() _now;
  final Duration fixTimeout;

  LocationFix? _fix;
  String? _error;
  LocationSource _source = LocationSource.none;
  Future<LatLng?>? _inFlight;

  /// Numbers each lookup so interleaved lines stay readable when a second
  /// tap arrives before the first has finished. TEMPORARY DIAGNOSTIC — see
  /// [_trace]; remove with the rest of the tracing once the indoor behaviour
  /// on real phones is understood.
  int _lookupCount = 0;

  /// Verbose tracing for the indoor-location investigation.
  ///
  /// Deliberately unconditional rather than `kDebugMode`-only: the readings
  /// that matter come from a real phone inside a real building, which may be
  /// running a profile or release build.
  void _trace(String message) => dev.log(message, name: 'LocationService');

  /// Last known position, live or remembered. May be stale — see [currentAge].
  LatLng? get current => _fix?.point;
  DateTime? get currentAt => _fix?.recordedAt;

  /// The radius the platform itself puts on [current], in metres. A satellite
  /// fix is single digits; a Wi-Fi/cell one is hundreds, which the address
  /// picker warns about rather than presenting as the customer's doorstep.
  double? get currentAccuracy => _fix?.accuracy;

  /// True when the last reading is too coarse to be taken as an exact spot.
  /// 100 m is roughly a city block here — beyond that the pin needs dragging.
  bool get currentIsApproximate => (_fix?.accuracy ?? 0) > 100;
  Duration? get currentAge =>
      currentAt == null ? null : _now().difference(currentAt!);
  bool get isStale => _fix != null && !_fix!.isFresh(_now());

  /// `location_service_off`, `location_permission_denied`, `location_no_fix`,
  /// `location_stale` or `location_unavailable`. Null once a live reading
  /// lands.
  String? get error => _error;

  /// Where the last [fetch] answer came from.
  LocationSource get lastSource => _source;

  /// True when the customer has to act on the phone before this can work —
  /// location switched off, or permission refused.
  ///
  /// Lives here rather than in each widget so the two maps cannot drift on
  /// which failures mean "grant a permission". The other failures happen with
  /// permission already granted, and telling that customer to visit settings
  /// sends them looking for a switch that is already on.
  bool get isBlocked =>
      _error == 'location_service_off' ||
      _error == 'location_permission_denied';

  /// True when the last answer must be presented as a starting point rather
  /// than the customer's actual spot: either the platform's own radius is
  /// coarse, or the point came out of the cache and describes where they were
  /// up to ten minutes ago.
  bool get lastResultIsApproximate =>
      _source == LocationSource.cached || currentIsApproximate;

  /// Fetches a position, asking for permission first if needed.
  ///
  /// Returns a fresh reading when the receiver produces one; otherwise a
  /// remembered one that is still recent enough to be useful; otherwise null,
  /// which the caller turns into a message the customer can act on.
  Future<LatLng?> fetch() {
    final running = _inFlight;
    if (running != null) {
      _trace('fetch() while #$_lookupCount is still running — joining it');
      return running;
    }
    final future = _fetch();
    _inFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future)) _inFlight = null;
      }),
    );
    return future;
  }

  Future<LatLng?> _fetch() async {
    final id = ++_lookupCount;
    final wall = Stopwatch()..start();
    StreamSubscription<loc.LocationData>? sub;
    _trace(
      '#$id start · budget=${fixTimeout.inMilliseconds}ms '
      'precise=${preciseAttempt.inMilliseconds}ms '
      'cached=${_fix == null ? 'none' : '${_fix!.point} '
                'age=${_now().difference(_fix!.recordedAt).inSeconds}s'}',
    );
    try {
      var serviceEnabled = await _location.serviceEnabled();
      _trace(
        '#$id serviceEnabled=$serviceEnabled (${wall.elapsedMilliseconds}ms)',
      );
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        _trace('#$id requestService -> $serviceEnabled');
        if (!serviceEnabled) return _fail('location_service_off');
      }

      var permission = await _location.hasPermission();
      _trace(
        '#$id hasPermission=${permission.name} (${wall.elapsedMilliseconds}ms)',
      );
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        _trace('#$id requestPermission -> ${permission.name}');
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        // A refusal is the customer's decision, not a gap to paper over with
        // a cached point.
        //
        // NOTE for the log reader: on Android 12+ a customer who picked
        // "Approximate" also lands here. The plugin checks ACCESS_FINE_LOCATION
        // only, so coarse-granted is indistinguishable from refused — see the
        // implementation note in INDOOR_LOCATION_TASK.md.
        return _fail('location_permission_denied');
      }

      // Started only now, after the permission and service dialogs: the
      // customer may sit on an OS prompt for a minute, and counting that
      // against the acquisition budget would time out a lookup that had not
      // begun. Everything from here is measured against this one clock —
      // monotonic, so a device clock change mid-lookup cannot skew it.
      final elapsed = Stopwatch()..start();
      Duration remaining() => fixTimeout - elapsed.elapsed;

      // A one-second interval rather than five: this is a single lookup the
      // customer is waiting on, not a background track, and the stream's
      // first emission is exactly what is being waited for.
      await _applySettings(loc.LocationAccuracy.high);

      final arrived = Completer<LatLng?>();
      var offered = 0;
      void offer(loc.LocationData data) {
        final n = ++offered;
        _trace(
          '#$id reading $n @${wall.elapsedMilliseconds}ms · '
          'lat=${data.latitude} lng=${data.longitude} '
          'acc=${data.accuracy} time=${data.time}',
        );

        final fix = LocationFix.fromData(data, _now());
        if (fix == null) {
          // Coordinates out of range, NaN/infinite, an impossible accuracy
          // radius, or a timestamp in the future — see LocationFix.fromData.
          _trace('#$id reading $n REJECTED as invalid');
          return;
        }

        // Two separate reasons a reading must not finish this lookup as a
        // *live* answer, and both used to let one through.
        //
        // `_remember` refuses a reading older than the one already held, but
        // the completer was told regardless — so a platform handing back its
        // last-known position from hours ago returned that as the customer's
        // current location, while `current`/`currentAccuracy` still described
        // the better reading. The pin then sat somewhere the customer had
        // been, with no warning, ready to be saved as a delivery address.
        //
        // Gating on acceptance also keeps the getters honest: whatever is
        // returned here is exactly what `_fix` now holds, so the approximate
        // check downstream describes the point the map actually moved to.
        if (!_remember(fix)) {
          // The one-shot read and the stream routinely deliver the *same*
          // measurement a few milliseconds apart, so "not newer" is usually a
          // duplicate rather than a stale reading. Saying which keeps the log
          // honest — an identical timestamp is nothing to worry about, an
          // older one is.
          final held = _fix?.recordedAt;
          final duplicate = held != null && fix.recordedAt == held;
          _trace(
            '#$id reading $n skipped — '
            '${duplicate ? 'duplicate of the one held' : 'older than the one '
                      'held (${held?.toIso8601String()})'}',
          );
          return;
        }

        // Still recent enough to mean "here, now". An older-but-newest
        // reading is kept above — it is the best thing to remember — but it
        // leaves through the cached path, which the UI marks approximate.
        if (!fix.isFresh(_now())) {
          _trace(
            '#$id reading $n stored but NOT live — recorded '
            '${_now().difference(fix.recordedAt).inSeconds}s ago, '
            'freshness is ${LocationFix.freshness.inSeconds}s',
          );
          return;
        }

        _trace(
          '#$id reading $n ACCEPTED as live: ${fix.point} acc=${fix.accuracy}',
        );
        if (!arrived.isCompleted) arrived.complete(fix.point);
      }

      sub = _location.onLocationChanged.listen(offer, onError: (Object _) {});
      unawaited(_location.getLocation().then(offer, onError: (Object _) {}));

      // Indoors the satellite attempt above produces nothing at all, so the
      // wait is split: give it [preciseAttempt], then ask the same receiver
      // for a network-based reading with whatever time is left. The stream
      // and the completer carry over, so a satellite fix that lands during
      // the second half is still the one that wins.
      //
      // Each phase gets only what is left of the one budget, so the tiers can
      // never add up to more than [fixTimeout]. The precise phase used to be
      // waited out in full regardless, which made a 50 ms timeout take six
      // seconds — the customer's spinner outlived the limit meant to bound it.
      final precise = _shorter(preciseAttempt, remaining());
      _trace('#$id precise phase: waiting ${precise.inMilliseconds}ms');
      var point = await _await(arrived.future, precise);

      if (point == null && remaining() > Duration.zero) {
        _trace(
          '#$id no satellite fix in ${precise.inMilliseconds}ms, '
          'falling back to network positioning with '
          '${remaining().inMilliseconds}ms left',
        );
        await _applySettings(loc.LocationAccuracy.balanced);
        // A fresh one-shot read: the previous one is already bound to the
        // old accuracy setting and may never answer.
        unawaited(_location.getLocation().then(offer, onError: (Object _) {}));
        point = await _await(arrived.future, remaining());
      } else if (point == null) {
        _trace('#$id budget already spent — no time for the network tier');
      }

      if (point != null) {
        _error = null;
        _source = LocationSource.live;
        notifyListeners();
        _trace(
          '#$id DONE live=$point acc=$currentAccuracy '
          'approximate=$lastResultIsApproximate (${wall.elapsedMilliseconds}ms)',
        );
        return point;
      }
      // Nothing from the receiver. A recent remembered position is a far
      // better answer than an error the customer cannot act on.
      final fallback = _recentCached();
      _fail(fallback == null ? 'location_no_fix' : 'location_stale');
      if (fallback != null) _source = LocationSource.cached;
      _trace(
        '#$id DONE no live fix · cached=$fallback error=$_error '
        'readings=$offered (${wall.elapsedMilliseconds}ms)',
      );
      return fallback;
    } catch (error, stackTrace) {
      dev.log(
        '#$id threw after ${wall.elapsedMilliseconds}ms',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
      final fallback = _recentCached();
      _fail(fallback == null ? 'location_unavailable' : 'location_stale');
      if (fallback != null) _source = LocationSource.cached;
      _trace('#$id DONE after error · cached=$fallback error=$_error');
      return fallback;
    } finally {
      await sub?.cancel();
    }
  }

  /// The reading if it lands within [limit], `null` if it does not — the
  /// timeout is an expected outcome of each tier here, not a failure.
  Future<LatLng?> _await(Future<LatLng?> fix, Duration limit) async {
    if (limit <= Duration.zero) return null;
    try {
      return await fix.timeout(limit);
    } on TimeoutException {
      return null;
    }
  }

  static Duration _shorter(Duration a, Duration b) => a <= b ? a : b;

  Future<void> _applySettings(loc.LocationAccuracy accuracy) async {
    try {
      _trace('changeSettings(accuracy: ${accuracy.name})');
      await _location.changeSettings(
        accuracy: accuracy,
        interval: 1000,
        distanceFilter: 0,
      );
    } catch (error) {
      // Not every platform implementation accepts this; the reads still work
      // with whatever settings are in force.
      _trace('changeSettings(${accuracy.name}) failed: $error');
    }
  }

  LatLng? _recentCached() {
    final fix = _fix;
    if (fix == null) return null;
    final age = _now().difference(fix.recordedAt);
    return !age.isNegative && age <= maxCacheAge ? fix.point : null;
  }

  /// Stores [fix] when it is newer than what is already held, and reports
  /// whether it did. Callers use the answer to decide whether this reading may
  /// also be handed back as the current position — see `offer`.
  bool _remember(LocationFix fix) {
    final previous = _fix;
    if (previous != null && !fix.recordedAt.isAfter(previous.recordedAt)) {
      return false;
    }
    _fix = fix;
    unawaited(
      Future<void>.sync(
        () => _prefs?.setString(_cacheKey, jsonEncode(fix.toJson())),
      ),
    );
    notifyListeners();
    return true;
  }

  void _restore() {
    final raw = _prefs?.getString(_cacheKey);
    if (raw == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      data['time'] = DateTime.parse(
        data['recordedAt'] as String,
      ).millisecondsSinceEpoch.toDouble();
      _fix = LocationFix.fromData(loc.LocationData.fromMap(data), _now());
    } catch (_) {
      // A corrupt cache is simply no cache.
    }
  }

  /// Records a failure. The source drops to [LocationSource.none] here so a
  /// refusal can never leave `lastSource` reading `live` from an earlier
  /// lookup; the two cached paths set it back to [LocationSource.cached]
  /// immediately after.
  Null _fail(String reason) {
    _error = reason;
    _source = LocationSource.none;
    dev.log(reason, name: 'LocationService');
    notifyListeners();
    return null;
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
