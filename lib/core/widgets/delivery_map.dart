import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../constants/app_config.dart';
import '../localization/locale_provider.dart';
import '../services/location_service.dart';
import '../services/tile_cache_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
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
    this.showMyLocation = true,
  });

  final LatLng? branchPoint;
  final LatLng? destinationPoint;
  final LatLng? courierPoint;
  final List<LatLng> routePoints;
  final EdgeInsets padding;
  final bool interactive;

  /// Shows the "centre on me" control. Ignored when [interactive] is false —
  /// a map the customer cannot pan has nothing to recentre.
  final bool showMyLocation;

  @override
  State<DeliveryMap> createState() => DeliveryMapState();
}

class DeliveryMapState extends State<DeliveryMap> {
  final MapController _controller = MapController();
  bool _fitted = false;

  /// The customer's own position, drawn only once they ask for it. Nothing
  /// here streams or uploads it — see [LocationService].
  LatLng? _myLocation;
  bool _locating = false;

  @override
  void didUpdateWidget(covariant DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fit once real points arrive, then let the courier drive without the
    // camera fighting the customer's own pan/zoom.
    if (!_fitted && widget.destinationPoint != null) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => fitAll());
      return;
    }

    // The courier's position and the road route are fetched separately and
    // land after that first fit, so the frame chosen then only covered the
    // address — leaving the courier off-screen exactly when someone is
    // looking for them. Re-fit on the one frame each of them first appears,
    // and only then: refitting on every courier move would yank the camera
    // away from wherever the customer had panned to.
    final courierArrived =
        oldWidget.courierPoint == null && widget.courierPoint != null;
    final routeArrived =
        oldWidget.routePoints.length < 2 && widget.routePoints.length > 1;
    if (courierArrived || routeArrived) {
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

  /// Fetches a single fix and centres on it, the way the same button behaves
  /// in the address picker. A refusal is reported rather than swallowed: the
  /// button visibly did nothing otherwise, and the reason — permission, or
  /// location switched off entirely — is the customer's to fix.
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    final location = context.read<LocationService>();
    dev.log('my-location button tapped', name: 'DeliveryMap');
    // Read before the await, and the spinner cleared in a `finally`: a widget
    // disposed mid-lookup, a throw, or a timeout all have to leave the button
    // usable again, not spinning over a request nobody is waiting on.
    LatLng? point;
    try {
      point = await location.fetch();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    dev.log(
      'fetch -> $point source=${location.lastSource.name} '
      'error=${location.error} approximate=${location.lastResultIsApproximate} '
      'mounted=$mounted',
      name: 'DeliveryMap',
    );
    if (!mounted) return;
    setState(() => _myLocation = point);

    final s = context.read<LocaleProvider>().strings;
    if (point == null) {
      // Only two of the four ways this gives up are the customer's to fix.
      // Indoors the permission is granted and the receiver simply has
      // nothing, and sending that customer to settings hunting for a switch
      // that is already on is worse than saying the map needs a manual pin.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location.isBlocked
                ? '${s.locationDenied} — ${s.locationDeniedHint}'
                : s.locationNoFix,
          ),
        ),
      );
      return;
    }

    // A coarse or remembered point is a good starting view and a bad claim
    // about where the customer is standing; say so rather than centring on it
    // silently.
    if (location.lastResultIsApproximate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.locationApproximate)));
    }
    _controller.move(point, AppConfig.pickZoom);
  }

  @override
  Widget build(BuildContext context) {
    final map = _buildMap();
    if (!widget.interactive || !widget.showMyLocation) return map;

    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          right: 16,
          // Lifted clear of whatever the screen has laid over the map — the
          // tracking sheet reports its own height through `padding`.
          bottom: widget.padding.bottom + 16,
          child: _MyLocationButton(loading: _locating, onTap: _goToMyLocation),
        ),
      ],
    );
  }

  Widget _buildMap() {
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
            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 22,
                height: 22,
                child: const _MyLocationDot(),
              ),
          ],
        ),
      ],
    );
  }
}

/// The customer's own position: a dot with a white collar so it stays legible
/// over both the pale streets and the dark parks of our tiles.
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, spreadRadius: 1),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.greenLight,
          ),
        ),
      ),
    );
  }
}

/// Matches the control of the same name in the address picker, so the gesture
/// means the same thing on both maps.
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: loading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.green,
                    ),
                  )
                : const HugeIcon(
                    icon: AppIcons.myLocation,
                    color: AppColors.green,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}
