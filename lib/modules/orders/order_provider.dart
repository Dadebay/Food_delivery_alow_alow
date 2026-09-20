import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/data/order_repository.dart';
import '../../core/constants/app_config.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/order.dart';
import '../../core/models/order_quote.dart';
import '../../core/models/order_status.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';

/// Order history plus the live state of whatever is currently in progress.
///
/// Real status changes come from the operator, the kitchen and the courier's
/// GPS (proposal slide 4) — this app only ever reads them. In demo mode there
/// is no backend to push those changes, so [_simulate] plays the same
/// sequence out locally on a compressed clock, purely so the tracking screen
/// has something honest to show.
class OrderProvider extends ChangeNotifier {
  OrderProvider({required OrderRepository repository, RoutingService? routing})
    : _repository = repository,
      _routing = routing ?? RoutingService();

  final OrderRepository _repository;
  final RoutingService _routing;

  List<CustomerOrder> _orders = [];
  bool _loading = true;
  Object? _error;
  bool _disposed = false;

  List<CustomerOrder> get orders => _orders;
  bool get loading => _loading;
  Object? get error => _error;

  CustomerOrder? get activeOrder {
    for (final order in _orders) {
      if (order.status.isOpen) return order;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _repository.orders();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrder> placeOrder({
    required List<CartItem> items,
    required DeliveryAddress address,
    required double subtotal,
    required double discount,
    double? changeFrom,
    String? promoCode,
    int? deliveryEtrapId,
    String? orderComment,
  }) async {
    final order = await _repository.place(
      items: items,
      address: address,
      subtotal: subtotal,
      discount: discount,
      changeFrom: changeFrom,
      promoCode: promoCode,
      deliveryEtrapId: deliveryEtrapId,
      orderComment: orderComment,
    );
    _orders = [order, ..._orders];
    notifyListeners();
    if (AppConfig.useMockData) unawaited(_simulate(order));
    return order;
  }

  /// The authoritative price of the current cart — item prices, promo
  /// discount and delivery fee, all recomputed by the backend — without
  /// placing an order. Checkout uses this for every number it shows before
  /// the customer taps "place order"; none of it is computed on the client.
  Future<OrderQuote> quote({
    required List<CartItem> items,
    required double subtotal,
    int? deliveryEtrapId,
    String? promoCode,
  }) => _repository.quote(
    items: items,
    subtotal: subtotal,
    deliveryEtrapId: deliveryEtrapId,
    promoCode: promoCode,
  );

  Future<void> rate(CustomerOrder order, int stars) async {
    order.rating = stars;
    notifyListeners();
    await _repository.rate(order.id, stars);
  }

  /// Cancels an order the customer can still back out of. The server only
  /// allows this while the order is still `NEW`; [CustomerOrder.isCancellable]
  /// additionally hides the button once [OrderStatus.customerCancelWindow]
  /// has passed, since by then it's unlikely to still be `NEW` server-side.
  /// In demo mode there's no backend to confirm against, so the status
  /// simply flips locally instead of making a request.
  Future<void> cancelOrder(CustomerOrder order, {required String reason}) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      order.status = OrderStatus.cancelled;
      notifyListeners();
      return;
    }
    final updated = await _repository.cancel(
      order.id,
      version: order.version,
      reason: reason,
    );
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) _orders[index] = updated;
    notifyListeners();
  }

  Future<void> refreshTracking(String orderId) async {
    if (AppConfig.useMockData) return;
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    try {
      final updated = await _repository.order(orderId);

      // Courier position and route are fetched separately, and each is
      // allowed to fail on its own. They used to share this method's single
      // `try`: one 404 from the courier-location endpoint threw before
      // `_orders[index] = updated` ever ran, so a failure there quietly
      // discarded the order refresh itself — status included.
      String courierNote;
      try {
        updated.courierPoint = await _repository.courierLocation(orderId);
        courierNote = updated.courierPoint == null
            ? 'null (no fix, or last fix older than 90s)'
            : '${updated.courierPoint!.latitude},'
                  '${updated.courierPoint!.longitude}';
      } catch (error) {
        courierNote = 'request failed: $error';
      }

      // Asking whenever the courier is visible rather than only after pickup.
      // The decision belongs to the backend: it answers `routingStatus` and
      // says READY only when it actually has a road to draw. Refusing to ask
      // while the order sits in ASSIGNED_TO_COURIER meant a route the server
      // could already produce was never requested — and that status is shown
      // as "courier on the way" too, so the map looked broken.
      String routeNote;
      if (!updated.status.courierVisible) {
        updated.routePoints = null;
        routeNote = 'not requested (courier not visible yet)';
      } else {
        try {
          updated.routePoints = await _repository.courierRoute(orderId);
          routeNote = updated.routePoints == null
              ? 'null (routingStatus not READY, or fewer than 2 points)'
              : '${updated.routePoints!.length} points';
        } catch (error) {
          updated.routePoints = null;
          routeNote = 'request failed: $error';
        }
      }

      _logTracking(updated, courierNote, routeNote);

      _orders[index] = updated;
      notifyListeners();
    } catch (error) {
      // The last known order state remains visible while the device is offline.
      if (kDebugMode) {
        debugPrint('\x1B[1;31m[TRACK #$orderId] refresh failed: $error\x1B[0m');
      }
    }
  }

  /// Says, in one place, why the tracking map does or does not have a line to
  /// draw. Every piece behind it can come back empty for its own reason, and
  /// each of those reasons used to be invisible from the outside.
  void _logTracking(CustomerOrder order, String courier, String route) {
    if (!kDebugMode) return;
    const cyan = '\x1B[1;36m';
    const yellow = '\x1B[1;33m';
    const green = '\x1B[1;32m';
    const red = '\x1B[1;31m';
    const reset = '\x1B[0m';

    final points = order.routePoints?.length ?? 0;
    final drawable = points > 1 || order.courierPoint != null;
    final verdict = drawable
        ? '${green}line WILL be drawn$reset'
        : '${red}no line: nothing to draw$reset';

    debugPrint('$cyan╔══ TRACK #${order.number} ══╗$reset');
    debugPrint('$cyan║$reset status   : $yellow${order.status.name}$reset');
    debugPrint('$cyan║$reset pickedUp : $yellow${order.pickedUp}$reset');
    debugPrint('$cyan║$reset courier  : $courier');
    debugPrint('$cyan║$reset route    : $route');
    debugPrint('$cyan║$reset verdict  : $verdict');
    debugPrint('$cyan╚═══════════════════╝$reset');
  }

  /// Walks a freshly placed order through the same stages a real one goes
  /// through, on a demo timescale: accepted → cooked → courier assigned and
  /// driving → delivered. Courier position is interpolated from the branch to
  /// the delivery address so the map on the tracking screen actually moves.
  Future<void> _simulate(CustomerOrder order) async {
    Future<void> wait(Duration d) => Future<void>.delayed(d);
    void tick() {
      if (!_disposed) notifyListeners();
    }

    await wait(const Duration(seconds: 3));
    if (_disposed || order.status == OrderStatus.cancelled) return;
    order.status = OrderStatus.accepted;
    order.acceptedAt = DateTime.now();
    tick();

    await wait(const Duration(seconds: 4));
    if (_disposed || order.status == OrderStatus.cancelled) return;
    order.status = OrderStatus.cooked;
    order.cookedAt = DateTime.now();
    tick();

    await wait(const Duration(seconds: 3));
    if (_disposed || order.status == OrderStatus.cancelled) return;
    final branch = order.branchPoint ?? LocationService.fallbackCenter;
    order.status = OrderStatus.onTheWay;
    order.courierName = 'Мырат Аннаев';
    order.courierPhone = '+99365123456';
    order.courierPoint = branch;
    order.pickedUp = true;

    // Same routing endpoint the courier app draws its own line from, so the
    // marker here travels along the exact route drawn on the map rather than
    // cutting across blocks in a straight line.
    final route = await _routing.route([branch, order.address.point]);
    final points = route.isEmpty ? [branch, order.address.point] : route.points;
    order.routePoints = points;

    final distanceKm = LocationService.kmBetween(branch, order.address.point);
    final minutes = (distanceKm / 25 * 60).clamp(8, 40).round();
    order.etaMinutesLow = minutes;
    order.etaMinutesHigh = minutes + 6;
    tick();

    // Step the courier marker along the fetched route over ~12 seconds — long
    // enough to see it travel, short enough not to make the demo drag.
    const steps = 15;
    for (var i = 1; i <= steps; i++) {
      await wait(const Duration(milliseconds: 800));
      if (_disposed || order.status != OrderStatus.onTheWay) return;
      final index = ((points.length - 1) * i / steps).round().clamp(
        0,
        points.length - 1,
      );
      order.courierPoint = points[index];
      tick();
    }

    if (_disposed) return;
    order.status = OrderStatus.delivered;
    order.deliveredAt = DateTime.now();
    tick();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
