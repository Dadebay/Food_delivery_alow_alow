import '../constants/app_config.dart';
import '../models/dish.dart';
import '../network/api_client.dart';
import 'mock/mock_data.dart';

/// Reads the menu. Categories and dishes rarely change mid-session, so this
/// has no writes of its own — favoriting is a customer-side toggle, not a
/// catalogue edit, and lives in [CatalogProvider].
class CatalogRepository {
  CatalogRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<DishCategory>> categories() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.categories;
    }
    final response = await _api.get(ApiPaths.categories);
    return (response.data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      return DishCategory(
        id: json['id'].toString(),
        name: json['name'] as String,
        imageUrl: _absoluteImageUrl(json['imageUrl']),
      );
    }).toList();
  }

  Future<List<Dish>> dishes() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.dishes();
    }
    // The server requires categoryId on this endpoint — there's no "give me
    // everything" call — so the full menu is every category's products
    // fetched in parallel and flattened.
    final cats = await categories();
    final perCategory = await Future.wait(
      cats.map((category) => dishesForCategory(category.id)),
    );
    return perCategory.expand((dishes) => dishes).toList();
  }

  Future<List<Dish>> dishesForCategory(String categoryId) async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.dishes()
          .where((dish) => dish.categoryId == categoryId)
          .toList();
    }
    final response = await _api.get(
      ApiPaths.products,
      query: {'categoryId': categoryId},
    );
    return _parseDishes(response.data);
  }

  List<Dish> _parseDishes(Object? data) {
    return (data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      return Dish(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        categoryId: json['categoryId'].toString(),
        imageUrl: _imageUrl(json['images']),
      );
    }).toList();
  }

  Future<Set<String>> favoriteIds() async {
    if (AppConfig.useMockData) return const {};
    final response = await _api.get(ApiPaths.favorites);
    return (response.data as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['productId'].toString())
        .toSet();
  }

  Future<void> setFavorite(String productId, bool active) async {
    if (AppConfig.useMockData) return;
    if (active) {
      await _api.put(ApiPaths.favoriteToggle(productId));
    } else {
      await _api.delete(ApiPaths.favoriteToggle(productId));
    }
  }

  String? _imageUrl(Object? images) {
    if (images is! List || images.isEmpty) return null;
    final first = images.first;
    if (first is! Map) return null;
    final url = first['url'];
    if (url is! String || url.isEmpty) return null;
    return _absoluteImageUrl(url);
  }

  String? _absoluteImageUrl(Object? rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return null;
    return Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl).toString();
  }

  static Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));
}
