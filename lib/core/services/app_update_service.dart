import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../models/app_version_info.dart';
import '../network/api_client.dart';

/// How far behind the store this build is.
enum UpdateStatus {
  /// Nothing to do — either up to date, or we could not find out.
  none,

  /// Newer build exists. Worth offering, never worth forcing.
  optional,

  /// Below the backend's `minSupportedVersion`: this build is blocked.
  required,
}

/// Decides whether this build may keep running.
///
/// Deliberately **fail-open**: any failure — no network, a 404 from a backend
/// that has no version endpoint yet, a malformed body — leaves the status at
/// [UpdateStatus.none]. Locking customers out of a working app because a
/// check could not be made would be a far worse bug than running one version
/// behind, and this app already spends time on networks where nothing
/// resolves at all.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  UpdateStatus _status = UpdateStatus.none;
  AppVersionInfo? _info;
  String _currentVersion = '';

  UpdateStatus get status => _status;
  AppVersionInfo? get info => _info;

  /// The marketing version of this build, e.g. `1.2.0` — shown on the update
  /// screen so a customer reporting a problem can read it out.
  String get currentVersion => _currentVersion;

  /// Dismissed for this session. Only ever consulted for an optional update;
  /// a required one cannot be dismissed at all.
  bool _optionalDismissed = false;
  bool get shouldPromptOptional =>
      _status == UpdateStatus.optional && !_optionalDismissed;

  void dismissOptional() {
    _optionalDismissed = true;
    notifyListeners();
  }

  Future<void> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      final response = await _api.get(
        ApiPaths.appVersion,
        query: {'platform': _platform},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300 || response.data is! Map<String, dynamic>) {
        return;
      }

      final info = AppVersionInfo.fromJson(
        response.data as Map<String, dynamic>,
      );
      _info = info;

      if (AppVersionInfo.compare(_currentVersion, info.minSupportedVersion) <
          0) {
        _status = UpdateStatus.required;
      } else if (AppVersionInfo.compare(_currentVersion, info.latestVersion) <
          0) {
        _status = UpdateStatus.optional;
      } else {
        _status = UpdateStatus.none;
      }

      dev.log(
        'current=$_currentVersion latest=${info.latestVersion} '
        'min=${info.minSupportedVersion} → ${_status.name}',
        name: 'AppUpdate',
      );
      notifyListeners();
    } catch (error) {
      // Swallowed on purpose — see the class doc. The customer keeps the app
      // they have.
      dev.log('version check skipped: $error', name: 'AppUpdate');
    }
  }

  /// Opens the store page, preferring whatever the backend sent so the link
  /// can be corrected without shipping a new build — which is precisely the
  /// thing a blocked customer cannot install.
  Future<bool> openStore() async {
    final url = _info?.storeUrl ?? _fallbackStoreUrl;
    if (url == null || url.isEmpty) return false;
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      dev.log('could not open $url: $error', name: 'AppUpdate');
      return false;
    }
  }

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  /// Android can always be reached by package name. iOS needs the numeric
  /// App Store id, which does not exist until the app is first submitted, so
  /// there is nothing sensible to hard-code here — the backend supplies it.
  static String? get _fallbackStoreUrl =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? null
      : 'https://play.google.com/store/apps/details?id=${AppConfig.androidPackageName}';
}
