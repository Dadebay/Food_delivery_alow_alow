enum DishPricingType { fixed, variant }

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
    this.pricingType = DishPricingType.fixed,
    this.minPrice,
    this.variantLabel,
    this.variants = const [],
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

  /// The backend-owned sale mode. A [DishPricingType.variant] dish always
  /// requires an explicit selected variant; variants are not inferred from
  /// their count because inactive variants may exist in other API views.
  final DishPricingType pricingType;

  /// Lowest active variant price, used only before a variant is selected.
  /// [price] remains the backwards-compatible API price.
  final double? minPrice;

  bool get hasVariants => pricingType == DishPricingType.variant;
  double get minimumPrice => minPrice ?? price;

  /// e.g. "Ölçeg" / "Размер" — the admin-defined name for what the
  /// variants of this dish vary by. Only meaningful when [hasVariants].
  final String? variantLabel;
  final List<DishVariant> variants;

  double get discountedPrice =>
      discountPercent == null ? price : price * (100 - discountPercent!) / 100;

  /// The price to show until a customer selects a variant.
  double get displayedBasePrice => hasVariants ? minimumPrice : discountedPrice;

  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
}

/// One sellable size/weight/portion of a [Dish] — its own price and photos,
/// configured in the admin panel. The backend is the source of truth for
/// [price]; nothing here is discounted client-side.
class DishVariant {
  const DishVariant({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final bool isActive;
}

class DishCategory {
  const DishCategory({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;

  /// The category cover selected in the admin panel. Product photos are only
  /// a fallback for categories that do not yet have their own cover.
  final String? imageUrl;
}
