import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import 'tile_cache_service.dart';

/// One map tile in the standard slippy-map scheme.
@immutable
class MapTile {
  const MapTile(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  String url(String template) => template
      .replaceFirst('{z}', '$z')
      .replaceFirst('{x}', '$x')
      .replaceFirst('{y}', '$y');

  @override
  bool operator ==(Object other) =>
      other is MapTile && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}

/// A latitude/longitude rectangle.
@immutable
class TileArea {
  const TileArea({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
  });

  final double south;
  final double west;
  final double north;
  final double east;
  final int minZoom;
  final int maxZoom;
}

/// Fills the map cache ahead of time so the map never opens as a grey grid.
///
/// The cache underneath already keeps every tile the customer has looked at,
/// but that only helps the *second* visit to a district. A customer who moves
/// the map somewhere new — or opens the address picker for the first time —
/// still waits on the network, and on a slow connection that wait reads as a
/// broken map.
///
/// So the delivery area is downloaded once, in the background, and refreshed
/// weekly. The tiles go into the very same store the map reads from, written
/// by the same cache interceptor, so nothing special happens at draw time:
/// the map simply finds every tile already there.
class TileSeedService {
  const TileSeedService._();

  static const _lastRunKey = 'map_tiles_seeded_at';

  /// How often the area is refreshed. Streets change slowly; a week keeps the
  /// map current without spending the customer's data on it.
  static const refreshInterval = Duration(days: 7);

  /// The whole delivery area, at the zooms a customer actually browses.
  ///
  /// The map opens at 14 and the address picker at 16. Zoom 16 over the whole
  /// area would be some three thousand tiles, so it is seeded only across the
  /// centre — see [_core] — and the outskirts fetch it on demand.
  static const _area = TileArea(
    south: 37.86,
    west: 58.17,
    north: 38.02,
    east: 58.55,
    minZoom: 12,
    maxZoom: 15,
  );

  /// The dense middle of the city, where the address picker is actually used.
  static const _core = TileArea(
    south: 37.90,
    west: 58.28,
    north: 37.99,
    east: 58.44,
    minZoom: 16,
    maxZoom: 16,
  );

  /// How many tiles may be in flight at once. The tile server is our own and
  /// this runs behind the customer's back, so it stays deliberately modest.
  static const _concurrency = 4;

  static bool _running = false;

  /// Downloads the area unless it was done within [refreshInterval].
  ///
  /// Safe to call on every launch: it returns immediately when the work is
  /// not due, and never throws — a map that failed to pre-load is a slower
  /// map, not a broken app.
  static Future<void> seedIfDue(SharedPreferences prefs) async {
    if (_running) return;
    final last = prefs.getInt(_lastRunKey);
    if (last != null) {
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      if (!age.isNegative && age < refreshInterval) {
        _log('skipped — last run ${age.inDays}d ago');
        return;
      }
    }

    _running = true;
    try {
      final tiles = plan();
      _log('starting — ${tiles.length} tiles');
      final failed = await _download(tiles);
      // Only a clean run resets the clock. A partial one is retried on the
      // next launch rather than left half-filled for a week.
      if (failed == 0) {
        await prefs.setInt(_lastRunKey, DateTime.now().millisecondsSinceEpoch);
        _log('done — ${tiles.length} tiles cached');
      } else {
        _log('incomplete — $failed of ${tiles.length} failed, will retry');
      }
    } catch (error) {
      _log('failed — $error');
    } finally {
      _running = false;
    }
  }

  /// Every tile the seed covers, de-duplicated across the two areas.
  static List<MapTile> plan() {
    final tiles = <MapTile>{};
    for (final area in [_area, _core]) {
      for (var z = area.minZoom; z <= area.maxZoom; z++) {
        tiles.addAll(tilesFor(area, z));
      }
    }
    return tiles.toList();
  }

  /// The tiles covering [area] at [zoom].
  ///
  /// Pure, and separated from the download so the arithmetic — the part that
  /// silently produces either four tiles or forty thousand — can be tested
  /// without touching the network.
  static List<MapTile> tilesFor(TileArea area, int zoom) {
    final scale = 1 << zoom;
    final left = _lonToX(area.west, scale);
    final right = _lonToX(area.east, scale);
    // Y grows southwards, so the north edge gives the smaller index.
    final top = _latToY(area.north, scale);
    final bottom = _latToY(area.south, scale);

    final tiles = <MapTile>[];
    for (var x = left; x <= right; x++) {
      for (var y = top; y <= bottom; y++) {
        tiles.add(MapTile(zoom, x, y));
      }
    }
    return tiles;
  }

  static int _lonToX(double lon, int scale) =>
      ((lon + 180) / 360 * scale).floor().clamp(0, scale - 1);

  static int _latToY(double lat, int scale) {
    final rad = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * scale;
    return y.floor().clamp(0, scale - 1);
  }

  /// Fetches every tile through a cache-writing Dio, and reports how many
  /// could not be had.
  static Future<int> _download(List<MapTile> tiles) async {
    final dio = Dio(
      BaseOptions(
        responseType: ResponseType.bytes,
        headers: const {'User-Agent': AppConfig.mapUserAgent},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        // A missing tile is an answer, not an exception to unwind through.
        validateStatus: (code) => code != null && code < 500,
      ),
    )..interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: TileCacheService.store,
          policy: CachePolicy.forceCache,
          maxStale: AppConfig.tileCacheMaxStale,
          hitCacheOnErrorExcept: const [],
        ),
      ),
    );

    var failed = 0;
    var done = 0;
    final queue = List<MapTile>.of(tiles);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final tile = queue.removeLast();
        try {
          final response = await dio.get<List<int>>(
            tile.url(AppConfig.mapTileUrl),
          );
          if (response.statusCode != 200) failed++;
        } catch (_) {
          failed++;
        }
        done++;
        // One line every few hundred tiles: enough to see it moving, not
        // enough to drown the console.
        if (done % 250 == 0) _log('$done/${tiles.length}');
      }
    }

    await Future.wait([
      for (var i = 0; i < _concurrency; i++) worker(),
    ]);
    dio.close(force: true);
    return failed;
  }

  static void _log(String message) {
    // ANSI: black on bright green, then green text.
    debugPrint('\x1B[30;102m TILES \x1B[0m \x1B[92m$message\x1B[0m');
  }
}
