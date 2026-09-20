import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Web and unsupported platforms keep an in-memory cache implementation.
FileSystem createCatalogImageCacheFileSystem(String _) => MemoryCacheSystem();
