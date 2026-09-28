import 'package:flutter/foundation.dart';

import '../constants/app_config.dart';
import '../models/cart_gift.dart';
import '../models/loyalty_account.dart';
import '../models/loyalty_gift.dart';
import '../network/api_client.dart';
import 'feature_availability.dart';
import 'mock/mock_data.dart';

/// The gift catalogue and the customer's point balance.
///
/// The app never computes points. It asks for the balance, shows what the
/// server says, and re-asks after anything that could have moved it — an
/// order placed, delivered or cancelled.
class LoyaltyRepository {
  LoyaltyRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Gifts that can be picked right now. Open to guests: browsing needs no
  /// token, only choosing one does.
  Future<List<LoyaltyGift>> gifts() async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return MockData.gifts;
    }
    final response = await _api.get(ApiPaths.loyaltyGifts);
    final code = response.statusCode ?? 0;
    if (isFeatureAbsent(code)) {
      throw FeatureUnavailableException(ApiPaths.loyaltyGifts, code);
    }
    final data = response.data;
    if (code < 200 || code >= 300 || data is! List) {
      throw StateError('Expected a list of gifts, got $code: $data');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => LoyaltyGift.fromJson(e, resolveImage: absoluteMediaUrl))
        .toList();
  }

  /// The signed-in customer's balance and recent operations.
  Future<LoyaltyAccount> me() async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return MockData.loyaltyAccount;
    }
    final response = await _api.get(ApiPaths.loyaltyMe);
    final code = response.statusCode ?? 0;
    if (isFeatureAbsent(code)) {
      throw FeatureUnavailableException(ApiPaths.loyaltyMe, code);
    }
    final data = response.data;
    if (code < 200 || code >= 300 || data is! Map<String, dynamic>) {
      throw StateError('Expected a loyalty account, got $code: $data');
    }
    if (kDebugMode) {
      debugPrint(
        '[Loyalty] balance=${data['pointsBalance']} '
        'entries=${(data['entries'] as List?)?.length ?? 0}',
      );
    }
    return LoyaltyAccount.fromJson(data);
  }

  /// Media paths arrive same-origin (`/api/v1/media/<uuid>.webp`) and are
  /// resolved against the API base, exactly as dish and category photos are.
  static String? absoluteMediaUrl(Object? rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl).toString();
  }
}

/// The gift lines to send with a quote or an order, in the shape the API
/// expects. Shared by both so the two requests can never disagree about the
/// cart — a quote for one basket and an order for another is exactly the
/// mismatch `idempotencyKey` cannot protect against.
List<Map<String, dynamic>> giftsPayload(List<CartGift> gifts) =>
    gifts.map((g) => g.toJson()).toList();
