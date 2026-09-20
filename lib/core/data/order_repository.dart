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
    /// Free-text note for this order — shown in the admin and printed on
    /// the main and kitchen receipts (`Order.customerNote` on the backend).
    /// Combined with the address's own intercom/delivery note below, since
    /// the server only has one comment slot per order.
    String? orderComment,
  }) async {
    // The server's own `@ArrayMinSize(1)` rejects this with a 400 anyway,
    // but catching it here avoids a wasted round-trip for what's always a
    // client-side bug (e.g. a double-tap racing an earlier `cart.clear()`)
    // rather than something the customer did.
    if (items.isEmpty) {
      if (kDebugMode) {
        debugPrint('[CreateOrder ${_ts()}] rejected before sending: cart is empty');
      }
      throw ArgumentError('Cannot place an order with an empty cart');
    }
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
      // A blank house used to leave a trailing comma the courier app then
      // printed verbatim ("Parahat 7, "). Join only the parts that exist.
      'address': [address.district, address.house]
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(', '),
      'latitude': address.point.latitude,
      'longitude': address.point.longitude,
      'entrance': address.entrance,
      'floor': address.floor,
      'apartment': address.apartment,
      'customerNote': _combinedCustomerNote(orderComment, address.note),
      'promoCode': ?promoCode,
      'deliveryEtrapId': ?deliveryEtrapId,
    };
    if (kDebugMode) {
      debugPrint('[CreateOrder ${_ts()}] POST ${ApiPaths.placeOrder}');
      debugPrint('[CreateOrder ${_ts()}] request body: ${_preview(body)}');
    }
    final response = await _api.post(ApiPaths.placeOrder, data: body);
    final code = response.statusCode ?? 0;
    if (kDebugMode) {
      debugPrint('[CreateOrder ${_ts()}] response HTTP $code: ${_preview(response.data)}');
    }
    if (code < 200 || code >= 300) {
      if (kDebugMode) _printOrderConflict(response);
      throw OrderPlacementException(code, _extractServerMessage(response.data));
    }
    return _fromJson(
      response.data as Map<String, dynamic>,
      fallbackItems: items,
    );
  }

  /// millisecond-precision so two requests a few ms apart still show as two
  /// distinct lines instead of looking simultaneous.
  static String _ts() => DateTime.now().toIso8601String().substring(11, 23);

  /// The backend has one `customerNote` slot per order (max 500 chars),
  /// shown in the admin and printed on both receipts — this is where the
  /// customer's own order comment and the address's intercom/delivery note
  /// get merged into it. Truncated defensively so two independently-capped
  /// fields can never add up to more than the server accepts.
  String? _combinedCustomerNote(String? orderComment, String? addressNote) {
    final parts = [orderComment, addressNote]
        .map((s) => s?.trim())
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>();
    final combined = parts.join('\n');
    if (combined.isEmpty) return null;
    return combined.length > 500 ? combined.substring(0, 500) : combined;
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

  /// Prints the server's rejection reason verbatim in a compact, visible
  /// box — any non-2xx from `POST /orders` is business validation (a bad
  /// promo code, an unavailable product, a 409 conflict, ...) rather than a
  /// transport failure, so the raw response body is the useful diagnostic.
  void _printOrderConflict(Response<dynamic> response, {String what = 'ORDER'}) {
    const red = '\x1B[1;31m';
    const yellow = '\x1B[1;33m';
    const cyan = '\x1B[1;36m';
    const reset = '\x1B[0m';
    final request = response.requestOptions;
    final code = response.statusCode;

    void line(String label, Object? value) =>
        debugPrint('$red║$reset ${label.padRight(8)}: $value');

    debugPrint('$red╔════════ $what REJECTED ════════╗$reset');
    line('WHEN', _ts());
    line('HTTP', '$yellow$code ${_statusName(code)}$reset');
    // Which call actually failed. Two endpoints price a cart and one creates
    // an order; the banner used to say only "REJECTED", so a failure had to
    // be matched to a request by eye from the surrounding lines.
    line('CALL', '$cyan${request.method} ${request.uri}$reset');
    // What we sent is half the answer — a 400 is almost always about the
    // body, and reading it next to the server's complaint is what turns
    // "Bad Request" into a fixable fact.
    line('SENT', _preview(request.data));
    line('SERVER', _preview(response.data));

    // class-validator returns one string per broken field. Printed as a list
    // they read as a checklist of what to fix instead of one run-on line.
    final reasons = _validationMessages(response.data);
    if (reasons.length > 1) {
      for (final reason in reasons) {
        debugPrint('$red║$reset          $yellow• $reason$reset');
      }
    }

    if (code == 401 || code == 403) {
      // The customer endpoints are open to customer accounts, so a 401/403
      // here is about *which* account is signed in, not about this request's
      // contents.
      line('TOKEN', '$yellow${_api.tokenRole}$reset');
    }

    final hint = _rejectionHint(code, reasons, request.data);
    if (hint != null) line('HINT', '$yellow$hint$reset');

    debugPrint('$red╚════════════════════════════════╝$reset');
  }

  static String _statusName(int? code) => switch (code ?? 0) {
    400 => '(Bad Request — the body failed validation)',
    401 => '(Unauthorized — no/expired token)',
    403 => '(Forbidden — wrong account role)',
    404 => '(Not Found — wrong path, or the product/order is gone)',
    409 => '(Conflict — stale version, or already taken)',
    422 => '(Unprocessable — business rule refused it)',
    >= 500 => '(Server error — retry it; the app sent a valid request)',
    _ => '',
  };

  /// Long bodies get cut: a twenty-item cart would otherwise push the
  /// server's own message off the top of the console.
  static String _preview(Object? value, {int max = 1200}) {
    final text = value?.toString() ?? 'null';
    return text.length > max ? '${text.substring(0, max)}… (${text.length} chars)' : text;
  }

  /// Every human-readable reason in a NestJS error body, one per entry.
  static List<String> _validationMessages(Object? data) {
    if (data is! Map) return const [];
    final message = data['message'];
    if (message is String) return [message];
    if (message is List) return message.whereType<String>().toList();
    return const [];
  }

  /// Turns the server's wording into the thing to actually go and check.
  /// Only for the failures we have already seen in the field — anything else
  /// gets no hint rather than a guessed one.
  String? _rejectionHint(int? code, List<String> reasons, Object? sentBody) {
    final joined = reasons.join(' ').toLowerCase();
    if (joined.contains('items must contain at least 1')) {
      return 'the cart was empty when this fired — most likely a re-quote '
          'triggered by the cart being cleared after a successful order';
    }
    if (joined.contains('promo')) {
      return 'promo code problem only — the cart itself priced fine';
    }
    if (joined.contains('productid') || joined.contains('variantid')) {
      return 'a cart line points at a product/variant the server does not '
          'have — stale catalogue, clear the cart and reload the menu';
    }
    if (joined.contains('latitude') || joined.contains('longitude')) {
      return 'the address has no valid pin — the map never resolved a point';
    }
    if (code == 401) return 'token expired — sign in again';
    if (code == 403) return 'signed in with a non-customer account';
    if (code == 400 && reasons.isEmpty) {
      return 'server sent no message field; the SENT body above is the only '
          'lead — compare it field by field against the endpoint DTO';
    }
    return null;
  }

  /// A GPS fix older than this is treated the same as no position at all —
  /// showing a courier marker frozen from ten minutes ago is worse than
  /// showing none, because it reads as their current location.
  static const _staleAfter = Duration(seconds: 90);

  Future<LatLng?> courierLocation(String orderId) async {
    final response = await _api.get(ApiPaths.courierLocation(orderId));
    if (kDebugMode) {
      final raw = response.data.toString();
      debugPrint(
        '\x1B[1;33m[COURIER LOC] order $orderId -> '
        '${raw.length > 300 ? '${raw.substring(0, 300)}…' : raw}\x1B[0m',
      );
    }
    final location = (response.data as Map<String, dynamic>)['location'];
    // "No signal at all" and "signal too old" are different problems — one is
    // the courier app not reporting, the other a courier who has gone out of
    // coverage — and collapsing both into a bare null hid which one it was.
    if (location is! Map<String, dynamic>) {
      if (kDebugMode) {
        debugPrint(
          '\x1B[1;33m[COURIER LOC] order $orderId: server has no location '
          'for this courier yet\x1B[0m',
        );
      }
      return null;
    }

    final recordedAt = DateTime.tryParse(
      location['recordedAt'] as String? ?? '',
    );
    if (recordedAt != null &&
        DateTime.now().toUtc().difference(recordedAt) > _staleAfter) {
      if (kDebugMode) {
        final age = DateTime.now().toUtc().difference(recordedAt);
        debugPrint(
          '\x1B[1;33m[COURIER LOC] order $orderId: last fix is '
          '${age.inSeconds}s old (limit ${_staleAfter.inSeconds}s) — '
          'courier app is not reporting\x1B[0m',
        );
      }
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
    // The server's own words, so a "not READY" can be handed to whoever owns
    // the routing service instead of being reported as "the map is broken".
    if (kDebugMode) {
      final raw = data.toString();
      debugPrint(
        '\x1B[1;33m[COURIER ROUTE] order $orderId -> '
        '${raw.length > 400 ? '${raw.substring(0, 400)}…' : raw}\x1B[0m',
      );
    }
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
    // An empty cart has nothing to price, and the server rejects it outright
    // ("items must contain at least 1 elements"). Checkout re-quotes whenever
    // the subtotal changes, and clearing the cart after a successful order is
    // such a change — so the request fired on the way out of a checkout that
    // had just worked, and printed an ORDER REJECTED banner for an order that
    // was already placed.
    if (items.isEmpty) {
      return const OrderQuote(
        subtotal: 0,
        discount: 0,
        discountedSubtotal: 0,
        deliveryFee: 0,
        total: 0,
      );
    }

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
    if (kDebugMode) {
      debugPrint('[OrderQuote ${_ts()}] POST ${ApiPaths.orderQuote}');
      // A one-line summary of *what* is being priced, so a wrong total can be
      // traced to the cart that produced it without re-reading the raw body.
      debugPrint(
        '[OrderQuote ${_ts()}] cart: ${items.length} line(s), '
        '${items.fold<int>(0, (sum, i) => sum + i.quantity)} item(s), '
        'subtotal $subtotal, etrap ${deliveryEtrapId ?? '—'}, '
        'promo ${promoCode ?? '—'}',
      );
      debugPrint('[OrderQuote ${_ts()}] request body: $body');
    }
    final response = await _api.post(ApiPaths.orderQuote, data: body);
    final code = response.statusCode ?? 0;
    if (kDebugMode) {
      debugPrint('[OrderQuote ${_ts()}] response HTTP $code: ${_preview(response.data)}');
    }
    if (code < 200 || code >= 300) {
      // Named apart from a real order rejection: this endpoint only prices a
      // cart, and a failure here leaves the customer's order untouched.
      if (kDebugMode) _printOrderConflict(response, what: 'QUOTE');
      throw OrderPlacementException(code, _extractServerMessage(response.data));
    }
    return OrderQuote.fromJson(response.data as Map<String, dynamic>);
  }

  String? _absoluteImageUrl(Object? rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return null;
    return Uri.parse(ApiClient.currentBaseUrl).resolve(rawUrl).toString();
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
