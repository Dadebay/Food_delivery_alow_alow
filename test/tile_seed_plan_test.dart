import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/services/tile_seed_service.dart';

/// The tile arithmetic is the part that silently decides whether the
/// pre-load costs four tiles or forty thousand, so it is pinned here rather
/// than discovered on a customer's data plan.
void main() {
  test('a one-tile world at zoom 0', () {
    const world = TileArea(
      south: -85,
      west: -180,
      north: 85,
      east: 180,
      minZoom: 0,
      maxZoom: 0,
    );
    expect(TileSeedService.tilesFor(world, 0), [const MapTile(0, 0, 0)]);
  });

  test('y grows southwards', () {
    const area = TileArea(
      south: 37.86,
      west: 58.17,
      north: 38.02,
      east: 58.55,
      minZoom: 14,
      maxZoom: 14,
    );
    final tiles = TileSeedService.tilesFor(area, 14);

    // A strip along each edge: the northern one must sit above the southern
    // one in tile space, which is the easiest thing to get backwards.
    int topY(double south, double north) => TileSeedService.tilesFor(
      TileArea(
        south: south,
        west: 58.17,
        north: north,
        east: 58.18,
        minZoom: 14,
        maxZoom: 14,
      ),
      14,
    ).map((t) => t.y).reduce((a, b) => a < b ? a : b);

    expect(topY(38.01, 38.02), lessThan(topY(37.86, 37.87)));
    // And the whole area covers both edges.
    expect(tiles.map((t) => t.y).reduce((a, b) => a < b ? a : b), topY(38.01, 38.02));
  });

  test('the url template is filled in', () {
    expect(
      const MapTile(14, 3, 7).url('https://x/tile/{z}/{x}/{y}.png'),
      'https://x/tile/14/3/7.png',
    );
  });

  test('the plan stays within a sane download size', () {
    final tiles = TileSeedService.plan();
    // Roughly 20-40 MB at typical tile weights. If a zoom level is ever added
    // to the seed, this is the line that should make someone stop and think.
    expect(tiles.length, greaterThan(500));
    expect(tiles.length, lessThan(2500));
    // Every tile appears once: the two areas overlap and must be merged.
    expect(tiles.toSet().length, tiles.length);
  });
}
