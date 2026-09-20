import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Keeps product and category images outside the OS temporary directory so
/// they remain available after the application process is closed.
class _PersistentCatalogImageFileSystem implements FileSystem {
  _PersistentCatalogImageFileSystem(this.key);

  final String key;
  Future<Directory>? _directory;

  Future<Directory> _getDirectory() => _directory ??= () async {
    final support = await getApplicationSupportDirectory();
    const local = LocalFileSystem();
    final directory = local.directory(path.join(support.path, key));
    await directory.create(recursive: true);
    return directory;
  }();

  @override
  Future<File> createFile(String name) async {
    var directory = await _getDirectory();
    if (!await directory.exists()) {
      _directory = null;
      directory = await _getDirectory();
    }
    return directory.childFile(name);
  }
}

FileSystem createCatalogImageCacheFileSystem(String key) =>
    _PersistentCatalogImageFileSystem(key);
