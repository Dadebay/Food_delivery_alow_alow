import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../models/cart_item.dart';
import '../models/delivery_address.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../network/api_client.dart';
import 'mock/mock_data.dart';

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
          .map((i) => {'productId': i.dish.id, 'quantity': i.quantity})
          .toList(),
      'addressLabel': 'Teslimat adresi',
      'address': '${address.district}, ${address.house}',
      'latitude': address.point.latitude,
      'longitude': address.point.longitude,
      'entrance': address.entrance,
      'floor': address.floor,
      'apartment': address.apartment,
      'customerNote': address.note,
      'promoCode': ?promoCode,
    };
    final response = await _api.post(ApiPaths.placeOrder, data: body);
    if (response.statusCode == 409 && kDebugMode) {
      _printOrderConflict(response);
    }
    _ensureSuccess(response);
    return _fromJson(
      response.data as Map<String, dynamic>,
      fallbackItems: items,
    );
  }

  Future<void> rate(String orderId, int stars) async {
    if (AppConfig.useMockData) return;
    await _api.post(ApiPaths.rateOrder(orderId), data: {'score': stars});
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

  Future<LatLng?> courierLocation(String orderId) async {
    final response = await _api.get(ApiPaths.courierLocation(orderId));
    final location = (response.data as Map<String, dynamic>)['location'];
    if (location is! Map<String, dynamic>) return null;
    return LatLng(
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
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
      return CartItem(
        dish: Dish(
          id: json['productId'].toString(),
          name: json['productName'] as String? ?? '',
          description: '',
          price: (json['unitPrice'] as num).toDouble(),
          categoryId: '',
          imageUrl: _absoluteImageUrl(json['productImageUrl']),
        ),
        quantity: json['quantity'] as int,
      );
    }).toList();
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
