/// One menu item.
///
/// [imageUrl] is an asset path (e.g. `assets/images/dishes/somsa.jpg`) or a
/// network URL once the backend serves real photos. The photo files
/// themselves aren't part of this change — `DishThumbnail` falls back to a
/// plain neutral tile wherever [imageUrl] is missing or fails to load.
class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.imageUrl,
    this.discountPercent,
    this.portionLabel,
    this.prepMinutes,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String? imageUrl;

  /// e.g. 15 for "-15%" — the weekly promo badge.
  final int? discountPercent;

  /// "4 шт", "3 шампура" — how the portion is counted.
  final String? portionLabel;
  final int? prepMinutes;

  /// Toggled locally by [CatalogProvider.toggleFavorite]; this is what the
  /// heart icon on the dish card reflects.
  bool isFavorite;

  double get discountedPrice =>
      discountPercent == null ? price : price * (100 - discountPercent!) / 100;

  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
}

class DishCategory {
  const DishCategory({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;

  /// The category cover selected in the admin panel. Product photos are only
  /// a fallback for categories that do not yet have their own cover.
  final String? imageUrl;
}
