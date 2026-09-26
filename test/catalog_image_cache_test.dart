import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/core/services/catalog_image_cache_manager.dart';
import 'package:food_delivery/core/widgets/brand_shimmer.dart';
import 'package:food_delivery/core/widgets/cart_fly_animation.dart';
import 'package:food_delivery/core/widgets/dish_thumbnail.dart';

void main() {
  testWidgets('product thumbnails use the persistent catalogue cache', (
    tester,
  ) async {
    final dish = Dish(
      id: 'dish-1',
      name: 'Manty',
      description: '',
      price: 20,
      categoryId: 'category-1',
      imageUrl: 'https://example.com/product.webp',
    );

    await tester.pumpWidget(MaterialApp(home: DishThumbnail(dish: dish)));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.cacheManager, same(CatalogImageCacheManager.instance));
    expect(CatalogImageCacheManager.instance.config.maxNrOfCacheObjects, 1000);
    expect(
      CatalogImageCacheManager.instance.config.stalePeriod,
      const Duration(days: 365),
    );

    final imageContext = tester.element(find.byType(CachedNetworkImage));
    await tester.pumpWidget(
      MaterialApp(
        home: image.errorWidget!(
          imageContext,
          image.imageUrl,
          Exception('unavailable'),
        ),
      ),
    );
    expect(find.byType(BrandShimmerBox), findsOneWidget);
    expect(find.text(BrandShimmerText.wordmark), findsOneWidget);
  });

  test('cart animation reuses the product image cache', () {
    final image = CartFlyAnimation.imageFor('https://example.com/product.webp');

    expect(image, isA<CachedNetworkImageProvider>());
    expect(
      (image! as CachedNetworkImageProvider).cacheManager,
      same(CatalogImageCacheManager.instance),
    );
  });
}
