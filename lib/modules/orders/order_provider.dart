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
  }) async {
    final order = await _repository.place(
      items: items,
      address: address,
      subtotal: subtotal,
      discount: discount,
      changeFrom: changeFrom,
      promoCode: promoCode,
      deliveryEtrapId: deliveryEtrapId,
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
      updated.courierPoint = await _repository.courierLocation(orderId);

      // Draws the actual driving line behind the courier marker, not just
      // the dot itself — from the backend, never a routing provider called
      // directly from the phone. Gated on pickedUp rather than
      // courierVisible — the courier is assigned and "on the way" from the
      // moment they're heading to the branch, but the road to *this* address
      // only exists once they've actually collected the order.
      updated.routePoints = updated.pickedUp
          ? await _repository.courierRoute(orderId)
          : null;

      _orders[index] = updated;
      notifyListeners();
    } catch (_) {
      // The last known order state remains visible while the device is offline.
    }
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
