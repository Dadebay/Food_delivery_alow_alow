import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';

/// Runs once per test file before its tests start.
///
/// `ApiClient` now opens a Hive-backed response cache on construction (see
/// `core/network/api_client.dart`) the same way `TileCacheService` already
/// does for map tiles — real app startup gives Hive a home directory via
/// `TileCacheService.init()` before any `ApiClient` exists, but a plain
/// `flutter test` run never does, so any test that builds an `ApiClient`
/// (directly, or indirectly through a repository) needs one too. A test that
/// cares about cache isolation between its own cases (see
/// `api_client_offline_cache_test.dart`) still points Hive at its own temp
/// directory in `setUp`/`tearDown` — this just keeps every other test from
/// having to know `ApiClient` uses Hive at all.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Hive.init(Directory.systemTemp.createTempSync('flutter_test_hive').path);
  await testMain();
}
