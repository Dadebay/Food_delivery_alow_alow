import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_config.dart';
import '../models/delivery_address.dart';
import '../models/delivery_quote.dart';
import '../models/saved_address.dart';
import '../network/api_client.dart';

class AddressRepository {
  AddressRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Asks the backend for the real delivery price at this point — the same
  /// per-etrap table admins manage. `null` on demo mode, no network, or an
  /// older backend that doesn't expose this endpoint yet — callers must
  /// show a loading state rather than invent a number in that case, never
  /// fall back to a client-computed rate.
  Future<DeliveryQuote?> quote({
    required LatLng point,
    required double subtotal,
  }) async {
    if (AppConfig.useMockData) return null;
    try {
      // Bounded separately from the client's own timeouts: `ApiClient` retries
      // an unreachable address against the fallback, so a single quote can sit
      // through two connect timeouts plus the delay between them. Checkout
      // cannot wait that long for a price.
      final response = await _api
          .post(
            ApiPaths.deliveryQuote,
            data: {
              'latitude': point.latitude,
              'longitude': point.longitude,
              'subtotal': subtotal,
            },
          )
          .timeout(AppConfig.deliveryQuoteTimeout);
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) return null;
      return DeliveryQuote.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<SavedAddress>> list() async {
    if (AppConfig.useMockData) return const [];
    final response = await _api.get(ApiPaths.addresses);
    final data = response.data;
    // The client accepts any status below 500 without throwing, so a 4xx
    // (eg. an expired token) still lands here as a normal response — just
    // with an error-envelope object instead of the expected array.
    if (data is! List) {
      throw StateError(
        'Expected a list of addresses, got ${response.statusCode}: $data',
      );
    }
    return data
        .map((item) => SavedAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Saves a brand-new address and makes it active — the server's own
  /// behaviour for this call, not something the client asks for separately.
  Future<void> create(DeliveryAddress address, {String? label}) async {
    if (AppConfig.useMockData) return;
    final response = await _api.post(
      ApiPaths.addresses,
      data: {
        if (label != null && label.isNotEmpty) 'label': label,
        // The server takes one free-text line, not district/house apart —
        // this is the same join CreateAddressDto's own example uses. The
        // house is optional in the form, and joining it blindly left the
        // line ending in a dangling ", " for every address saved without
        // one.
        'address': address.apiLine,
        'latitude': address.point.latitude,
        'longitude': address.point.longitude,
        if (address.entrance != null) 'entrance': address.entrance,
        if (address.floor != null) 'floor': address.floor,
        if (address.apartment != null) 'apartment': address.apartment,
      },
    );
    // The client treats every 4xx as a normal response so call sites can read
    // error bodies, which meant a rejected address looked exactly like a saved
    // one here: the screen returned happily and the address simply never
    // appeared. Fail loudly instead.
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      final body = response.data;
      // The thrown message is what the customer's screen may end up showing,
      // so it stays short. The full body is what actually explains a 400 —
      // NestJS validation lists every rejected field in it — and it is only
      // useful in the log next to the payload that caused it.
      debugPrint(
        '[Address] create failed: HTTP $code body=$body '
        'line="${address.apiLine}" '
        'lat=${address.point.latitude} lng=${address.point.longitude}',
      );
      final message = switch (body) {
        Map m when m['message'] is String => m['message'] as String,
        // `message` is a list of strings for validation errors.
        Map m when m['message'] is List => (m['message'] as List).join(', '),
        _ => 'HTTP $code',
      };
      throw StateError('Address was not saved: $message');
    }
  }

  Future<void> activate(String id) async {
    if (AppConfig.useMockData) return;
    await _api.post('${ApiPaths.addresses}/$id/activate');
  }

  Future<void> remove(String id) async {
    if (AppConfig.useMockData) return;
    await _api.delete('${ApiPaths.addresses}/$id');
  }
}
