import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'catalog_image_cache_file_system.dart';

/// Shared persistent cache for product, variant, and category images.
///
/// The backend gives each upload a new UUID URL and marks it immutable for a
/// year. Keeping those files in application support storage is therefore safe
/// and avoids downloading the menu again after every application restart.
class CatalogImageCacheManager extends CacheManager with ImageCacheManager {
  CatalogImageCacheManager._()
    : super(
        Config(
          cacheKey,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: 1000,
          fileSystem: createCatalogImageCacheFileSystem(cacheKey),
        ),
      );

  static const cacheKey = 'naharymCatalogImagesV1';
  static final instance = CatalogImageCacheManager._();
}
