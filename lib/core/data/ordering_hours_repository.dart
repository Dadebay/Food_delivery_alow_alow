import '../constants/app_config.dart';
import '../models/ordering_hours.dart';
import '../network/api_client.dart';

/// Whether the restaurant is taking orders.
///
/// Every failure mode resolves to [OrderingHours.unrestricted]. Locking the
/// order button because a status request timed out would turn a network
/// blip into a closed shop; the server rejects an out-of-hours order at
/// creation time anyway, and that rejection is the real gate.
class OrderingHoursRepository {
  OrderingHoursRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<OrderingHours> hours() async {
    if (AppConfig.useMockData) return OrderingHours.unrestricted;
    try {
      final response = await _api
          .get(ApiPaths.orderingHours)
          .timeout(AppConfig.deliveryQuoteTimeout);
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) return OrderingHours.unrestricted;
      final data = response.data;
      if (data is! Map<String, dynamic>) return OrderingHours.unrestricted;
      return OrderingHours.fromJson(data);
    } catch (_) {
      return OrderingHours.unrestricted;
    }
  }
}
