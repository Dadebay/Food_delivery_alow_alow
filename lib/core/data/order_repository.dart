import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../models/cart_item.dart';
import '../models/delivery_address.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../models/order_quote.dart';
import '../models/order_status.dart';
import '../network/api_client.dart';
import 'mock/mock_data.dart';

/// Thrown when the backend rejects an order — carries the server's own
/// message (e.g. "Promo code is unavailable") so the UI can show a specific,
/// translated reason instead of the raw error body.
class OrderPlacementException implements Exception {
  OrderPlacementException(this.statusCode, this.serverMessage);

  final int statusCode;
  final String? serverMessage;

  @override
  String toString() =>
      serverMessage ?? 'Order request failed with $statusCode';
}

/// Places orders and reads order history.
///
/// Status progress after placing (accepted → cooked → on the way →
/// delivered) is not modelled here — that is real kitchen/operator/courier
/// activity on the server. [OrderProvider] drives a demo simulation of it in
/// mock mode so the tracking screen has something to show.
class OrderRepository {
  OrderRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<CustomerOrder>> orders() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return _seedHistory();
    }
    final response = await _api.get(ApiPaths.orders);
    _ensureSuccess(response);
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerOrder> place({
    required List<CartItem> items,
    required DeliveryAddress address,
    required double subtotal,
    required double discount,
    double? changeFrom,
    String? promoCode,
    int? deliveryEtrapId,
  }) async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return CustomerOrder(
        id: 'ord-${DateTime.now().microsecondsSinceEpoch}',
        number: 1000 + DateTime.now().second,
        status: OrderStatus.placed,
        items: items,
        address: address,
        subtotal: subtotal,
        deliveryFee: AppConfig.deliveryFeeFor(subtotal),
        discount: discount,
        changeFrom: changeFrom,
        placedAt: DateTime.now(),
        branchPoint: MockData.branchPoint,
        branchName: MockData.branchName,
      );
    }

    final body = {
      'items': items
          .map(
            (i) => {
              'productId': i.dish.id,
              if (i.variant != null) 'variantId': i.variant!.id,
              'quantity': i.quantity,
            },
          )
          .toList(),
      'addressLabel': 'Gowşuryş salgysy',
      'address': '${address.district}, ${address.house}',
      'latitude': address.point.latitude,
      'longitude': address.point.longitude,
      'entrance': address.entrance,
      'floor': address.floor,
      'apartment': address.apartment,
      'customerNote': address.note,
      'promoCode': ?promoCode,
      'deliveryEtrapId': ?deliveryEtrapId,
    };
    final response = await _api.post(ApiPaths.placeOrder, data: body);
    if (response.statusCode == 409 && kDebugMode) {
      _printOrderConflict(response);
    }
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw OrderPlacementException(code, _extractServerMessage(response.data));
    }
    return _fromJson(
      response.data as Map<String, dynamic>,
      fallbackItems: items,
    );
  }

  /// NestJS error bodies are `{statusCode, message, error}`, with `message`
  /// either a single string (business validation, e.g. a bad promo code) or
  /// an array of strings (class-validator field errors) — either way this is
  /// the human-readable reason, worth showing instead of the raw JSON.
  String? _extractServerMessage(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    final message = data['message'];
    if (message is String) return message;
    if (message is List) return message.whereType<String>().join(', ');
    return null;
  }

  Future<void> rate(String orderId, int stars) async {
    if (AppConfig.useMockData) return;
    await _api.post(ApiPaths.rateOrder(orderId), data: {'score': stars});
  }

  /// Cancels an order the customer can still back out of. The deployed
  /// server only permits this while the order is still `NEW`, so once an
  /// operator has confirmed it this comes back 403 — surfaced as
  /// `order_too_late` so the UI can explain it instead of showing a generic
  /// failure. `version` guards against cancelling a stale copy — the server
  /// rejects that with a 409 if the order moved on since it was last fetched.
  Future<CustomerOrder> cancel(
    String orderId, {
    required int version,
    required String reason,
  }) async {
    final response = await _api.patch(
      ApiPaths.cancelOrder(orderId),
      data: {'reason': reason, 'version': version},
    );
    if (response.statusCode == 409) {
      throw StateError('order_conflict');
    }
    if (response.statusCode == 403) {
      throw StateError('order_too_late');
    }
    _ensureSuccess(response);
    return _fromJson(response.data as Map<String, dynamic>);
  }

  Future<CustomerOrder> order(String id) async {
    final response = await _api.get(ApiPaths.order(id));
    _ensureSuccess(response);
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// `ApiClient` accepts any status below 500 without throwing (several
  /// call sites need to read a 4xx body directly), so an expired token or
  /// other rejected request still lands here as a normal response — this
  /// turns that into a clear error instead of a `Map`-is-not-`List` style
  /// cast crash further down.
  void _ensureSuccess(Response<dynamic> response) {
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw StateError('Order request failed with $code: ${response.data}');
    }
  }

  /// Prints the server's conflict reason verbatim in a compact, visible box.
  /// A 409 is business validation (for example an already-open order), not a
  /// transport failure, so the response body is the useful diagnostic.
  void _printOrderConflict(Response<dynamic> response) {
    const red = '\x1B[1;31m';
    const yellow = '\x1B[1;33m';
    const reset = '\x1B[0m';
    debugPrint('$red╔════════ ORDER REJECTED ════════╗$reset');
    debugPrint('$red║$reset HTTP: $yellow${response.statusCode}$reset');
    debugPrint('$red║$reset SERVER: ${response.data}');
    debugPrint('$red╚════════════════════════════════╝$reset');
  }

  /// A GPS fix older than this is treated the same as no position at all —
  /// showing a courier marker frozen from ten minutes ago is worse than
  /// showing none, because it reads as their current location.
  static const _staleAfter = Duration(seconds: 90);

  Future<LatLng?> courierLocation(String orderId) async {
    final response = await _api.get(ApiPaths.courierLocation(orderId));
    final location = (response.data as Map<String, dynamic>)['location'];
    if (location is! Map<String, dynamic>) return null;

    final recordedAt = DateTime.tryParse(
      location['recordedAt'] as String? ?? '',
    );
    if (recordedAt != null &&
        DateTime.now().toUtc().difference(recordedAt) > _staleAfter) {
      return null;
    }

    return LatLng(
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
  }

  /// Road route from the courier's live position to this order's address —
  /// asks the backend for it rather than a routing provider directly, so the
  /// line is always the same one the courier is actually driving. Returns
  /// `null` when there's nothing to draw yet: not picked up, or the routing
  /// service is temporarily unavailable.
  Future<List<LatLng>?> courierRoute(String orderId) async {
    final response = await _api.get(ApiPaths.courierRoute(orderId));
    final data = response.data;
    if (data is! Map<String, dynamic> || data['routingStatus'] != 'READY') {
      return null;
    }
    final geometry = data['geometry'];
    if (geometry is! Map<String, dynamic> ||
        geometry['coordinates'] is! List<dynamic>) {
      return null;
    }
    final coords = (geometry['coordinates'] as List<dynamic>)
        .whereType<List<dynamic>>();
    if (coords.length < 2) return null;
    // GeoJSON is [lng, lat]; LatLng is the other way round.
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  /// A handful of history entries so the tab (and the "повтор в одно
  /// касание" reorder button) has something to show on first launch, before
  /// the customer places anything themselves — one order still in flight,
  /// two delivered, one cancelled, so every status the history card and
  /// filter can display actually shows up in the demo.
  List<CustomerOrder> _seedHistory() {
    final dishes = {for (final d in MockData.dishes()) d.id: d};
    final branch = MockData.branchPoint;

    // A couple of kilometres from the branch — a distinct customer address,
    // not the branch's own coordinates. Reusing the branch point here was
    // the actual bug behind "the pin shows a car": with the address and the
    // courier both sitting on the exact same coordinate, the courier marker
    // (drawn last, on top) simply covered the destination pin.
    final home = LatLng(branch.latitude + 0.018, branch.longitude + 0.024);

    DeliveryAddress address() => DeliveryAddress(
      district: 'Parahat 7',
      house: '12',
      entrance: '3',
      floor: '5',
      point: home,
    );

    List<CartItem> items(List<String> dishIds) =>
        dishIds.map((id) => CartItem(dish: dishes[id]!)).toList();

    double subtotalOf(List<CartItem> items) =>
        items.fold<double>(0, (sum, i) => sum + i.lineTotal);

    final onTheWayItems = items(['plov-chicken', 'lagman', 'tea-green']);
    final onTheWayPlaced = DateTime.now().subtract(const Duration(minutes: 22));
    final onTheWay = CustomerOrder(
      id: 'ord-hist-active',
      number: 1042,
      status: OrderStatus.onTheWay,
      items: onTheWayItems,
      address: address(),
      subtotal: subtotalOf(onTheWayItems),
      deliveryFee: AppConfig.deliveryFee,
      placedAt: onTheWayPlaced,
      acceptedAt: onTheWayPlaced.add(const Duration(minutes: 2)),
      cookedAt: onTheWayPlaced.add(const Duration(minutes: 12)),
      courierName: 'Мырат Аннаев',
      courierPhone: '+99365123456',
      // Partway along the branch → home line, not sitting on either end.
      courierPoint: LatLng(
        branch.latitude + (home.latitude - branch.latitude) * 0.6,
        branch.longitude + (home.longitude - branch.longitude) * 0.6,
      ),
      pickedUp: true,
      branchPoint: branch,
      branchName: MockData.branchName,
      etaMinutesLow: 8,
      etaMinutesHigh: 14,
    );

    final delivered1Items = items(['somsa-meat', 'churek']);
    final delivered1Ago = const Duration(days: 2, hours: 3);
    final delivered1 = CustomerOrder(
      id: 'ord-hist-1',
      number: 1031,
      status: OrderStatus.delivered,
      items: delivered1Items,
      address: address(),
      subtotal: subtotalOf(delivered1Items),
      deliveryFee: AppConfig.deliveryFee,
      placedAt: DateTime.now().subtract(delivered1Ago),
      deliveredAt: DateTime.now().subtract(
        delivered1Ago - const Duration(minutes: 25),
      ),
      branchPoint: branch,
      branchName: MockData.branchName,
      rating: 5,
    );

    final delivered2Items = items(['plov-ashgabat', 'ayran']);
    final delivered2Ago = const Duration(days: 6);
    final delivered2 = CustomerOrder(
      id: 'ord-hist-2',
      number: 1018,
      status: OrderStatus.delivered,
      items: delivered2Items,
      address: address(),
      subtotal: subtotalOf(delivered2Items),
      deliveryFee: AppConfig.deliveryFee,
      placedAt: DateTime.now().subtract(delivered2Ago),
      deliveredAt: DateTime.now().subtract(
        delivered2Ago - const Duration(minutes: 25),
      ),
      branchPoint: branch,
      branchName: MockData.branchName,
      rating: 4,
    );

    final cancelledItems = items(['shashlyk-lamb', 'dograma']);
    final cancelledAgo = const Duration(days: 9, hours: 5);
    final cancelled = CustomerOrder(
      id: 'ord-hist-cancelled',
      number: 1005,
      status: OrderStatus.cancelled,
      items: cancelledItems,
      address: address(),
      subtotal: subtotalOf(cancelledItems),
      deliveryFee: AppConfig.deliveryFee,
      placedAt: DateTime.now().subtract(cancelledAgo),
      branchPoint: branch,
      branchName: MockData.branchName,
    );

    return [onTheWay, delivered1, delivered2, cancelled];
  }

  CustomerOrder _fromJson(
    Map<String, dynamic> json, {
    List<CartItem> fallbackItems = const [],
  }) => CustomerOrder(
    id: json['id'].toString(),
    number: json['number'] as int,
    status: OrderStatus.fromWire(json['status'] as String?),
    pickedUp: json['status'] == 'OUT_FOR_DELIVERY',
    items: _itemsFromJson(json['items'], fallbackItems),
    address: DeliveryAddress(
      district: json['address'] as String? ?? '',
      house: '',
      entrance: json['entrance'] as String?,
      floor: json['floor'] as String?,
      apartment: json['apartment'] as String?,
      note: json['customerNote'] as String?,
      point: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    ),
    subtotal: (json['subtotal'] as num).toDouble(),
    deliveryFee: (json['deliveryFee'] as num).toDouble(),
    discount: (json['discount'] as num).toDouble(),
    version: (json['version'] as num?)?.toInt() ?? 1,
    placedAt: DateTime.parse(json['createdAt'] as String),
    deliveredAt: _date(json['deliveredAt']),
    branchPoint: _branchPoint(json),
    branchName: json['branchName'] as String?,
    courierName: _fullName(json['courier']),
    courierPhone: (json['courier'] as Map?)?['phone'] as String?,
    rating: (json['rating'] as Map?)?['score'] as int?,
  );

  List<CartItem> _itemsFromJson(Object? source, List<CartItem> fallback) {
    if (source is! List) return fallback;
    return source.map((item) {
      final json = item as Map<String, dynamic>;
      final unitPrice = (json['unitPrice'] as num).toDouble();
      final variantId = json['productVariantId'];
      final variantName = json['variantName'] as String?;
      return CartItem(
        dish: Dish(
          id: json['productId'].toString(),
          name: json['productName'] as String? ?? '',
          description: '',
          price: unitPrice,
          categoryId: '',
          imageUrl: _absoluteImageUrl(json['productImageUrl']),
        ),
        // A historical order line already carries the price it was bought
        // at — this variant only exists to show its name and that price
        // next to the dish, not to be re-priced against the live catalogue.
        variant: variantId == null
            ? null
            : DishVariant(
                id: variantId.toString(),
                name: variantName ?? '',
                price: unitPrice,
              ),
        quantity: json['quantity'] as int,
      );
    }).toList();
  }

  /// Asks the backend for the authoritative price of the current cart —
  /// item prices, the promo discount and the delivery fee, all recomputed
  /// server-side — without creating an order. This is the only source the
  /// app uses for the delivery fee and the promo discount shown before an
  /// order is placed; nothing here is guessed or computed on the client.
  Future<OrderQuote> quote({
    required List<CartItem> items,
    required double subtotal,
    int? deliveryEtrapId,
    String? promoCode,
  }) async {
    if (AppConfig.useMockData) {
      // No backend to ask in demo mode — this is the one place a flat rate
      // stands in for a real quote, and only because there is nothing else
      // to call.
      await _demoDelay();
      double discount = 0;
      if (promoCode != null && promoCode.trim().isNotEmpty) {
        const demoCodes = {'WELCOME15': 0.15, 'DEMO10': 0.10};
        final pct = demoCodes[promoCode.trim().toUpperCase()];
        if (pct == null) {
          throw OrderPlacementException(400, 'Promo code is unavailable');
        }
        discount = double.parse((subtotal * pct).toStringAsFixed(2));
      }
      final deliveryFee = AppConfig.deliveryFeeFor(subtotal);
      final discountedSubtotal = subtotal - discount;
      return OrderQuote(
        subtotal: subtotal,
        discount: discount,
        discountedSubtotal: discountedSubtotal,
        deliveryFee: deliveryFee,
        total: discountedSubtotal + deliveryFee,
      );
    }

    final body = {
      'items': items
          .map(
            (i) => {
              'productId': i.dish.id,
              if (i.variant != null) 'variantId': i.variant!.id,
              'quantity': i.quantity,
            },
          )
          .toList(),
      'deliveryEtrapId': ?deliveryEtrapId,
      'promoCode': ?promoCode,
    };
    final response = await _api.post(ApiPaths.orderQuote, data: body);
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw OrderPlacementException(code, _extractServerMessage(response.data));
    }
    return OrderQuote.fromJson(response.data as Map<String, dynamic>);
  }

  String? _absoluteImageUrl(Object? rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl).toString();
  }

  LatLng? _branchPoint(Map<String, dynamic> json) {
    final latitude = json['branchLatitude'];
    final longitude = json['branchLongitude'];
    if (latitude is! num || longitude is! num) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  String? _fullName(Object? source) {
    if (source is! Map) return null;
    final parts = [
      source['firstName'],
      source['lastName'],
    ].whereType<String>().where((part) => part.isNotEmpty);
    final name = parts.join(' ');
    return name.isEmpty ? null : name;
  }

  static Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 400));
}
