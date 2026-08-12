import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../services/location_service.dart';
import '../services/tile_cache_service.dart';
import '../theme/app_colors.dart';
import 'car_marker.dart';

/// The map on the order-tracking screen: branch → courier → customer's own
/// address, on our own tile server. Deliberately dumb — [OrderProvider] owns
/// the courier's simulated position and the route line; this widget just
/// draws whatever it is given.
class DeliveryMap extends StatefulWidget {
  const DeliveryMap({
    super.key,
    this.branchPoint,
    this.destinationPoint,
    this.courierPoint,
    this.routePoints = const [],
    this.padding = EdgeInsets.zero,
    this.interactive = true,
  });

  final LatLng? branchPoint;
  final LatLng? destinationPoint;
  final LatLng? courierPoint;
  final List<LatLng> routePoints;
  final EdgeInsets padding;
  final bool interactive;

  @override
  State<DeliveryMap> createState() => DeliveryMapState();
}

class DeliveryMapState extends State<DeliveryMap> {
  final MapController _controller = MapController();
  bool _fitted = false;

  @override
  void didUpdateWidget(covariant DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fit once real points arrive, then let the courier drive without the
    // camera fighting the customer's own pan/zoom.
    if (!_fitted && widget.destinationPoint != null) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => fitAll());
    }
  }

  void fitAll() {
    final points = [
      ...widget.routePoints,
      if (widget.branchPoint != null) widget.branchPoint!,
      if (widget.destinationPoint != null) widget.destinationPoint!,
      if (widget.courierPoint != null) widget.courierPoint!,
    ];
    if (points.length < 2) {
      if (points.length == 1 && mounted) {
        _controller.move(points.first, AppConfig.pickZoom);
      }
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: widget.padding + const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter:
            widget.destinationPoint ??
            widget.branchPoint ??
            LocationService.fallbackCenter,
        initialZoom: AppConfig.defaultZoom,
        minZoom: AppConfig.minZoom,
        maxZoom: AppConfig.maxZoom,
        backgroundColor: AppColors.cream,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: AppConfig.mapUserAgent,
          tileProvider: TileCacheService.tileProvider,
          keepBuffer: 3,
        ),
        if (widget.routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                strokeWidth: 9,
                color: AppColors.white.withValues(alpha: 0.9),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
              Polyline(
                points: widget.routePoints,
                strokeWidth: 5.5,
                color: AppColors.orange,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.branchPoint != null)
              Marker(
                point: widget.branchPoint!,
                width: 26,
                height: 26,
                child: const BranchMarker(),
              ),
            if (widget.destinationPoint != null)
              Marker(
                point: widget.destinationPoint!,
                width: 44,
                height: 44 * DestinationPin.heightRatio,
                alignment: Alignment.topCenter,
                child: const DestinationPin(),
              ),
            if (widget.courierPoint != null)
              Marker(
                point: widget.courierPoint!,
                width: 54,
                height: 54,
                child: const CarMarker(),
              ),
          ],
        ),
      ],
    );
  }
}
