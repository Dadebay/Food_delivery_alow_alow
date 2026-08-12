import '../constants/app_config.dart';
import '../models/promotion_banner.dart';
import '../network/api_client.dart';
import 'mock/mock_data.dart';

class MarketingRepository {
  MarketingRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<PromotionBanner>> banners() async {
    if (AppConfig.useMockData) {
      return MockData.bannerImages
          .asMap()
          .entries
          .map(
            (entry) => PromotionBanner(
              id: 'mock-banner-${entry.key}',
              title: 'Kampanya',
              imageUrl: entry.value,
            ),
          )
          .toList();
    }
    final response = await _api.get(ApiPaths.banners);
    return (response.data as List<dynamic>)
        .map(
          (item) => PromotionBanner.fromJson(
            _withAbsoluteImageUrl(item as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _withAbsoluteImageUrl(Map<String, dynamic> json) {
    final imageUrl = json['imageUrl'];
    if (imageUrl is! String || imageUrl.isEmpty) return json;
    return {
      ...json,
      'imageUrl': Uri.parse(AppConfig.apiBaseUrl).resolve(imageUrl).toString(),
    };
  }
}
