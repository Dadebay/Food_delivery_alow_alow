import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/models/order_status.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/delivery_map.dart';
import 'order_provider.dart';
import 'widgets/courier_contact_row.dart';
import 'widgets/order_rating_row.dart';
import 'widgets/status_timeline.dart';

/// Live tracking — matches `cust_track.png`: map with the route, delivery
/// time + distance, the four-step timeline, courier contact, and a rating
/// prompt once delivered.
class OrderTrackScreen extends StatefulWidget {
  const OrderTrackScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  Timer? _trackingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<OrderProvider>().refreshTracking(widget.orderId),
    );
    _trackingTimer = Timer.periodic(
      AppConfig.trackingPollInterval,
      (_) => context.read<OrderProvider>().refreshTracking(widget.orderId),
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  CustomerOrder? _find(OrderProvider provider) {
    for (final order in provider.orders) {
      if (order.id == widget.orderId) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final order = _find(context.watch<OrderProvider>());
    final online = context.watch<ConnectivityService>().online;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final distanceKm = _distanceKm(order);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: DeliveryMap(
              branchPoint: order.branchPoint,
              destinationPoint: order.address.point,
              courierPoint: order.status.courierVisible
                  ? order.courierPoint
                  : null,
              // Only draw the road once the courier has actually picked up
              // the order — before that they're heading to the branch, not
              // to this address, so there's no real route to show yet.
              routePoints: order.pickedUp
                  ? (order.routePoints ?? const [])
                  : const [],
              padding: const EdgeInsets.fromLTRB(0, 120, 0, 320),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _MapBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  _Pill(
                    color: AppColors.green,
                    child: Text(
                      s.orderNumber(order.number),
                      style: AppText.chip.copyWith(color: AppColors.white),
                    ),
                  ),
                  const Spacer(),
                  _Pill(
                    color: AppColors.white,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? AppColors.greenLight
                                : AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          online ? s.onlineBadge : s.offlineNoConnection,
                          style: AppText.chip.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomSheet(
              order: order,
              strings: s,
              distanceKm: distanceKm,
              onCall: _call,
            ),
          ),
        ],
      ),
    );
  }

  double? _distanceKm(CustomerOrder order) {
    final branch = order.branchPoint;
    if (branch == null) return null;
    final points = order.routePoints;
    if (points == null || points.length < 2) {
      return LocationService.kmBetween(branch, order.address.point);
    }
    var meters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      meters += const Distance().as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return meters / 1000;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: AppColors.shadow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: child,
      ),
    );
  }
}

class _MapBackButton extends StatelessWidget {
  const _MapBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: const CircleBorder(),
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: HugeIcon(
            icon: AppIcons.back,
            color: AppColors.green,
            size: 21,
          ),
        ),
      ),
    ),
  );
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.order,
    required this.strings,
    required this.distanceKm,
    required this.onCall,
  });

  final CustomerOrder order;
  final AppStrings strings;
  final double? distanceKm;
  final Future<void> Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    final s = strings;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (order.status.isOpen && order.etaMinutesLow != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.deliveryTimeLabel,
                              style: AppText.label.copyWith(
                                color: AppColors.greenMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.etaRange(
                                order.etaMinutesLow!,
                                order.etaMinutesHigh!,
                              ),
                              style: AppText.h1.copyWith(fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.distanceLabel,
                            style: AppText.label.copyWith(
                              color: AppColors.greenMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Fmt.km(distanceKm),
                            style: AppText.h1.copyWith(fontSize: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              StatusTimeline(order: order, strings: s),
              const Divider(),
              const SizedBox(height: 6),
              if (order.status == OrderStatus.onTheWay &&
                  order.courierName != null)
                CourierContactRow(order: order, strings: s, onCall: onCall)
              else if (order.status == OrderStatus.delivered)
                OrderRatingRow(order: order, strings: s),
            ],
          ),
        ),
      ),
    );
  }
}
