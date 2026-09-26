import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
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

/// Decides whether this build may keep running and whether a published store
/// update should be offered.
///
/// Backend policy and store discovery are independent and deliberately
/// **fail-open**. A 404 from the not-yet-deployed backend endpoint must not
/// hide a real App Store/Google Play update, and a store lookup failure must
/// not disable the backend's minimum-version gate.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({required ApiClient api, Upgrader? storeUpgrader})
    : _api = api,
      _store = storeUpgrader ?? Upgrader() {
    _storeSubscription = _store.stateStream.listen(_handleStoreState);
  }

  final ApiClient _api;
  final Upgrader _store;
  late final StreamSubscription<UpgraderState> _storeSubscription;

  UpdateStatus _status = UpdateStatus.none;
  AppVersionInfo? _info;
  AppVersionInfo? _backendInfo;
  AppVersionInfo? _storeInfo;
  String _currentVersion = '';
  bool _initialCheckComplete = false;

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
    } catch (error) {
      dev.log('installed version unavailable: $error', name: 'AppUpdate');
      return;
    }

    await Future.wait([_checkBackend(), _checkStore()]);
    _initialCheckComplete = true;
    _resolveStatus();
  }

  Future<void> _checkBackend() async {
    try {
      final response = await _api.get(
        ApiPaths.appVersion,
        query: {'platform': _platform},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300 || response.data is! Map<String, dynamic>) {
        _log('backend said HTTP $code — store lookup decides alone');
        return;
      }
      _backendInfo = AppVersionInfo.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      dev.log('backend version check skipped: $error', name: 'AppUpdate');
    }
  }

  Future<void> _checkStore() async {
    try {
      await _store.initialize();
      _storeInfo = _storeVersionInfo();
    } catch (error) {
      _log('store lookup failed: $error');
    }
  }

  void _handleStoreState(UpgraderState _) {
    _storeInfo = _storeVersionInfo();
    if (_initialCheckComplete) _resolveStatus();
  }

  AppVersionInfo? _storeVersionInfo() {
    final latest = _store.currentAppStoreVersion;
    if (latest == null || latest.isEmpty) return null;

    final notes = _store.releaseNotes;
    return AppVersionInfo(
      latestVersion: latest,
      minSupportedVersion: '0.0.0',
      storeUrl: _store.currentAppStoreListingURL,
      releaseNotesRu: notes,
      releaseNotesTk: notes,
    );
  }

  void _resolveStatus() {
    final previousLatest = _info?.latestVersion;
    final info = AppVersionInfo.mergeSources(
      backend: _backendInfo,
      store: _storeInfo,
    );
    _info = info;

    if (info == null) {
      _status = UpdateStatus.none;
    } else if (AppVersionInfo.compare(
          _currentVersion,
          info.minSupportedVersion,
        ) <
        0) {
      _status = UpdateStatus.required;
    } else if (AppVersionInfo.compare(_currentVersion, info.latestVersion) <
        0) {
      _status = UpdateStatus.optional;
    } else {
      _status = UpdateStatus.none;
    }

    if (previousLatest != null &&
        info != null &&
        AppVersionInfo.compare(info.latestVersion, previousLatest) > 0) {
      _optionalDismissed = false;
    }

    _log(
      'current=$_currentVersion  backend=${_backendInfo?.latestVersion ?? "—"}  '
      'store=${_storeInfo?.latestVersion ?? "—"}  '
      'min=${info?.minSupportedVersion ?? "—"}  → ${_status.name}',
    );
    notifyListeners();
  }

  /// Debug only. Which of the two sources decided the prompt is the whole
  /// question when an update keeps being offered to someone who has already
  /// installed it — and `dart:developer`'s log only reaches DevTools, which
  /// is exactly where nobody is looking when that happens.
  static void _log(String message) {
    // ANSI: black on bright blue, then blue text.
    debugPrint('\x1B[30;104m UPDATE \x1B[0m \x1B[94m$message\x1B[0m');
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

  @override
  void dispose() {
    _storeSubscription.cancel();
    _store.dispose();
    super.dispose();
  }
}
