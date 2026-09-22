import 'package:flutter/foundation.dart';


import '../constants/app_config.dart';
import '../models/cafe.dart';
import '../models/dish.dart';
import '../network/api_client.dart';
import 'mock/mock_data.dart';

/// Reads the menu. Categories and dishes rarely change mid-session, so this
/// has no writes of its own — favoriting is a customer-side toggle, not a
/// catalogue edit, and lives in [CatalogProvider].
class CatalogRepository {
  CatalogRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// The cafes a customer can browse, already ordered the way they should be
  /// listed. Only active cafes come back.
  Future<List<Cafe>> cafes() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.cafes;
    }
    final response = await _api.get(ApiPaths.cafes);
    final cafes = (response.data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      return Cafe(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: _absoluteImageUrl(json['imageUrl']),
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    // The contract asks for sortOrder then name. Sorting here rather than
    // trusting the response keeps the selector stable even if a future
    // endpoint returns them unordered.
    cafes.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.name.compareTo(b.name);
    });
    return cafes;
  }

  /// [cafeId] narrows the menu to one cafe. Omitting it is the legacy
  /// behaviour — the whole combined catalogue — which older releases still
  /// depend on.
  Future<List<DishCategory>> categories({String? cafeId}) async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.categoriesForCafe(cafeId);
    }
    final response = await _api.get(
      ApiPaths.categories,
      query: cafeId == null ? null : {'cafeId': cafeId},
    );
    return (response.data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      return DishCategory(
        id: json['id'].toString(),
        name: json['name'] as String,
        imageUrl: _absoluteImageUrl(json['imageUrl']),
      );
    }).toList();
  }

  /// The whole menu in one call.
  ///
  /// `categoryId` is optional on this endpoint — leaving it off returns every
  /// active product. This used to fan out into one request per category and
  /// wait for all of them, which meant 30-odd round trips before the home
  /// screen could paint anything; a phone only opens a handful of connections
  /// at a time, so those requests queued up in waves.
  Future<List<Dish>> dishes({String? cafeId}) async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.dishesForCafe(cafeId);
    }
    final response = await _api.get(
      ApiPaths.products,
      query: cafeId == null ? null : {'cafeId': cafeId},
    );
    return _parseDishes(response.data);
  }

  /// The two filters compose: a category belonging to another cafe returns
  /// nothing rather than leaking that cafe's products.
  Future<List<Dish>> dishesForCategory(
    String categoryId, {
    String? cafeId,
  }) async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.dishesForCafe(cafeId)
          .where((dish) => dish.categoryId == categoryId)
          .toList();
    }
    final response = await _api.get(
      ApiPaths.products,
      query: {'categoryId': categoryId, 'cafeId': ?cafeId},
    );
    return _parseDishes(response.data);
  }

  List<Dish> _parseDishes(Object? data) {
    final dishes = (data as List<dynamic>).map((e) {
      final json = e as Map<String, dynamic>;
      final images = _imageUrls(json['images']);
      // The admin panel's chosen cover leads the gallery whether or not it
      // is also in `images` — otherwise a dish opens on one photo and the
      // first swipe lands back on that same photo.
      final display = _absoluteImageUrl(json['displayImageUrl']);
      final gallery = display != null && !images.contains(display)
          ? <String>[display, ...images]
          : images;
      return Dish(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        categoryId: json['categoryId'].toString(),
        imageUrl: display ?? (images.isEmpty ? null : images.first),
        pricingType: _pricingType(json['pricingType']),
        minPrice: (json['minPrice'] as num?)?.toDouble(),
        variantLabel: json['variantLabel'] as String?,
        variants: _parseVariants(json['variants']),
        imageUrls: gallery,
      );
    }).toList();
    assert(() {
      if (!_loggedGallery) {
        _loggedGallery = true;
        final counts = dishes.map((d) => d.gallery.length).toList()..sort();
        _shout(
          'photos per dish: ${counts.isEmpty ? 0 : counts.last} max, '
          '${counts.where((c) => c > 1).length}/${counts.length} with a gallery',
        );
      }
      return true;
    }());
    return dishes;
  }

  List<DishVariant> _parseVariants(Object? data) {
    if (data is! List) return const [];
    return data
        .map((e) {
          final json = e as Map<String, dynamic>;
          return DishVariant(
            id: json['id'].toString(),
            name: json['name'] as String,
            price: (json['price'] as num).toDouble(),
            description: json['description'] as String?,
            imageUrl: _imageUrl(json['images']),
            imageUrls: _imageUrls(json['images']),
            isActive: json['isActive'] as bool? ?? true,
          );
        })
        .where((variant) => variant.isActive)
        .toList();
  }

  DishPricingType _pricingType(Object? value) =>
      value == 'VARIANT' ? DishPricingType.variant : DishPricingType.fixed;

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

  /// Every usable photo in an `images` array, in the order it arrived —
  /// the dish page swipes through these. Entries without a real url are
  /// dropped rather than turned into blank pages.
  List<String> _imageUrls(Object? images) {
    if (images is! List) return const [];
    final urls = <String>[];
    for (final entry in images) {
      final resolved = _absoluteImageUrl(_rawImageUrl(entry));
      if (resolved != null && !urls.contains(resolved)) urls.add(resolved);
    }
    return urls;
  }

  String? _imageUrl(Object? images) {
    if (images is! List || images.isEmpty) return null;
    return _absoluteImageUrl(_rawImageUrl(images.first));
  }

  /// One entry of an `images` array. It is normally `{"url": "..."}`, but a
  /// plain string and the other key the admin API uses for the same thing
  /// are both accepted — reading only `url` meant a gallery of four photos
  /// silently collapsed to the single cover image.
  Object? _rawImageUrl(Object? entry) {
    if (entry is String) return entry;
    if (entry is! Map) return null;
    return entry['url'] ?? entry['imageUrl'] ?? entry['path'];
  }

  String? _absoluteImageUrl(Object? rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return null;
    final resolved = Uri.parse(ApiClient.currentBaseUrl).resolve(rawUrl).toString();
    assert(() {
      if (!_loggedImageUrl) {
        _loggedImageUrl = true;
        _shout('first image url: $rawUrl → $resolved');
      }
      return true;
    }());
    return resolved;
  }

  /// Debug only — one line per run, enough to see what the menu's photos
  /// actually point at without a line per dish.
  static bool _loggedImageUrl = false;

  /// Debug only — says in one line whether the backend is actually sending
  /// more than the cover photo, which is the first thing to check when the
  /// dish page has nothing to swipe through.
  static bool _loggedGallery = false;

  /// Debug only. `dart:developer`'s log goes to the DevTools logging view,
  /// which is easy to miss when you are watching the run console — this goes
  /// straight there, in colour, so it cannot be scrolled past unnoticed.
  static void _shout(String message) {
    // ANSI: bright black on yellow, then reset.
    debugPrint('\x1B[30;103m CATALOG \x1B[0m \x1B[93m$message\x1B[0m');
  }

  static Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));
}
