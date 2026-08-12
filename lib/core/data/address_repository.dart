import '../constants/app_config.dart';
import '../models/delivery_address.dart';
import '../models/saved_address.dart';
import '../network/api_client.dart';

class AddressRepository {
  AddressRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

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
    await _api.post(
      ApiPaths.addresses,
      data: {
        if (label != null && label.isNotEmpty) 'label': label,
        // The server takes one free-text line, not district/house apart —
        // this is the same join CreateAddressDto's own example uses.
        'address': '${address.district}, ${address.house}',
        'latitude': address.point.latitude,
        'longitude': address.point.longitude,
        if (address.entrance != null) 'entrance': address.entrance,
        if (address.floor != null) 'floor': address.floor,
        if (address.apartment != null) 'apartment': address.apartment,
      },
    );
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
