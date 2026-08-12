import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../network/api_client.dart';
import '../services/push_device_registration_service.dart';

/// Phone + SMS code sign-in (proposal slide 5) — no passwords, and no name to
/// type either; the account is just the verified phone number.
class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required SharedPreferences prefs,
    required PushDeviceRegistrationService pushDevices,
  }) : _api = api,
       _prefs = prefs,
       _pushDevices = pushDevices;

  static const String _tokenKey = 'customer_token';
  static const String _phoneKey = 'customer_phone';
  static const String _refreshTokenKey = 'customer_refresh_token';
  static const String _displayNameKey = 'customer_display_name';
  static const String _avatarPathKey = 'customer_avatar_path';
  static const String _demoCode = '000000';

  final ApiClient _api;
  final SharedPreferences _prefs;
  final PushDeviceRegistrationService _pushDevices;

  /// Set by [AuthProvider] so a session that gets cleared mid-app (a real
  /// refresh-token failure, not just an access-token blip) is reflected in
  /// the UI immediately instead of only on the next app start.
  void Function()? onSessionExpired;

  String? get token => _prefs.getString(_tokenKey);
  bool get isSignedIn => token != null;
  String? get signedInPhone => _prefs.getString(_phoneKey);
  String get displayName =>
      _prefs.getString(_displayNameKey) ?? signedInPhone ?? '';

  /// The name as actually stored, with no phone-number fallback — empty
  /// when the customer hasn't set one, so an edit field can start blank
  /// instead of prefilled with their phone number.
  String get storedName => _prefs.getString(_displayNameKey) ?? '';

  /// Local file path for the customer's chosen avatar, if any — `null`
  /// falls back to the initials/icon placeholder.
  String? get avatarPath {
    final path = _prefs.getString(_avatarPathKey);
    return path != null && File(path).existsSync() ? path : null;
  }

  /// In demo mode there's no real account behind the phone/code flow, so a
  /// fresh install auto-signs-in as a demo customer — otherwise every tab
  /// that requires an account (Orders, Profile) would show nothing but a
  /// sign-in prompt on first launch, with no way to see the seeded mock data
  /// without first running the phone + code screen. Signing out still works
  /// normally, and the phone/code flow is still there to demo (code `0000`)
  /// once signed out.
  void restore() {
    if (AppConfig.useMockData && token == null) {
      unawaited(_prefs.setString(_tokenKey, 'demo-token'));
      unawaited(_prefs.setString(_phoneKey, '+99361234567'));
    }
    _api.token = token;
    if (!AppConfig.useMockData && token != null) {
      unawaited(_pushDevices.register());
      unawaited(_refreshProfile());
    }
  }

  Future<void> requestCode(String phone) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return;
    }
    // Installation metadata is strictly best-effort: a Firebase issue must
    // never prevent a customer from receiving an OTP.
    final body = <String, dynamic>{'phone': phone};
    try {
      body['installationId'] = await FirebaseInstallations.instance.getId();
    } catch (error, stackTrace) {
      debugPrint('Could not obtain Firebase installation ID: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    }
    body['deviceName'] = _deviceName();
    final platform = _apiPlatform();
    if (platform != null) body['platform'] = platform;

    final response = await _api.post(ApiPaths.requestCode, data: body);
    if (kDebugMode && response.data is Map<String, dynamic>) {
      final devCode = response.data['devCode'];
      if (devCode is String && devCode.isNotEmpty) {
        _printDevCode(devCode);
      }
    }
  }

  /// Boxed and ANSI-coloured so it can't be missed scrolling past normal
  /// Dio/Flutter log noise in a terminal `flutter run` console.
  void _printDevCode(String code) {
    const yellow = '\x1B[1;33m';
    const green = '\x1B[1;32m';
    const reset = '\x1B[0m';
    const width = 28;
    const prefix = '   OTP CODE:  ';
    final line = '═' * width;
    final padding = ' ' * (width - prefix.length - code.length);
    debugPrint('$green╔$line╗$reset');
    debugPrint('$green║$reset$prefix$yellow$code$reset$padding$green║$reset');
    debugPrint('$green╚$line╝$reset');
  }

  String _deviceName() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };

  // The backend currently distinguishes Android and iOS push platforms. For
  // desktop targets we still send a device name but omit the enum field.
  String? _apiPlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'IOS',
    TargetPlatform.android => 'ANDROID',
    _ => null,
  };

  Future<bool> verify({
    required String phone,
    required String code,
    String? firstName,
  }) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (code != _demoCode) return false;
      await _persist(token: 'demo-token', phone: phone, displayName: firstName);
      return true;
    }

    final response = await _api.post(
      ApiPaths.verifyCode,
      data: {
        'phone': phone,
        'code': code,
        // Only sent the first time — the sign-up name field, not asked
        // again once the account already has one.
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      },
    );
    if (response.statusCode != 200) return false;

    final data = response.data as Map<String, dynamic>;
    final token = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (token == null) return false;

    final user = data['user'] as Map<String, dynamic>?;
    final displayName = [
      user?['firstName'],
      user?['lastName'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    await _persist(
      token: token,
      phone: user?['phone'] as String? ?? phone,
      refreshToken: refreshToken,
      displayName: displayName,
    );
    await _pushDevices.register();
    return true;
  }

  Future<void> signOut() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    try {
      if (!AppConfig.useMockData) {
        await _pushDevices.unregister();
        if (refreshToken != null) {
          await _api.post(
            ApiPaths.logout,
            data: {'refreshToken': refreshToken},
          );
        }
      }
    } finally {
      await _clearSession();
    }
  }

  /// Trades the stored refresh token for a new access token — wired into
  /// [ApiClient.onUnauthorized], so a request that hits a normal 401 (the
  /// access token is only good for 15 minutes) gets one retry instead of
  /// surfacing as a crash.
  ///
  /// The refresh token is single-use and rotates on every call, which makes
  /// concurrent callers dangerous: the app fires several requests in
  /// parallel (catalog, orders, addresses, push registration, …), so a
  /// token expiring mid-session means two or three of them can 401 at
  /// nearly the same moment. Each would otherwise call this independently —
  /// the first swaps the refresh token for a new one, and the second, still
  /// holding the now-already-used token, gets rejected by the server and
  /// wipes the session that the first call just saved. That's the "signed
  /// in one moment, logged out after a hot restart" symptom: the wipe
  /// happens silently mid-session, and only becomes visible the next time
  /// the app reads the (now-empty) stored token on launch. Caching the
  /// in-flight future means every concurrent 401 waits on and shares the
  /// exact same refresh call instead of racing it.
  Future<bool> refreshSession() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool>? _refreshInFlight;

  Future<bool> _doRefresh() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (refreshToken == null) return false;
    try {
      final response = await _api.post(
        ApiPaths.refresh,
        data: {'refreshToken': refreshToken},
      );
      if (response.statusCode != 200) {
        await _clearSession();
        onSessionExpired?.call();
        return false;
      }
      final data = response.data as Map<String, dynamic>;
      final token = data['accessToken'] as String?;
      if (token == null) {
        await _clearSession();
        onSessionExpired?.call();
        return false;
      }
      await _persist(
        token: token,
        phone: signedInPhone ?? '',
        refreshToken: data['refreshToken'] as String?,
      );
      return true;
    } catch (_) {
      // A network hiccup during refresh isn't proof the session is dead —
      // clearing here would log the customer out for a dropped connection.
      // The next request will simply retry the refresh.
      return false;
    }
  }

  Future<void> _clearSession() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_phoneKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_displayNameKey);
    await _prefs.remove(_avatarPathKey);
    _api.token = null;
  }

  Future<void> _persist({
    required String token,
    required String phone,
    String? refreshToken,
    String? displayName,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_phoneKey, phone);
    if (refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
    }
    if (displayName != null) {
      await _prefs.setString(_displayNameKey, displayName);
    }
    _api.token = token;
  }

  /// Saves a new display name and/or profile photo.
  ///
  /// `/users/me` is GET-only on the backend today — there's no endpoint yet
  /// to persist a name or photo server-side. Everything is still saved
  /// locally (so the change shows immediately and survives an app
  /// restart on this device), and a picked photo is uploaded through the
  /// existing generic media endpoint so a URL is ready to send. The PATCH
  /// call below is forward-looking: once the backend adds profile
  /// updates, this starts working end-to-end with no app change.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    File? avatarFile,
  }) async {
    String? avatarUrl;
    if (avatarFile != null) {
      await _prefs.setString(
        _avatarPathKey,
        await _cacheAvatarLocally(avatarFile),
      );
      if (!AppConfig.useMockData) {
        try {
          final form = FormData.fromMap({
            'file': await MultipartFile.fromFile(avatarFile.path),
          });
          final response = await _api.post(ApiPaths.mediaUpload, data: form);
          if (response.statusCode == 201) {
            avatarUrl =
                (response.data as Map<String, dynamic>)['url'] as String?;
          }
        } catch (_) {
          // The photo still shows locally even if the upload failed.
        }
      }
    }

    final displayName = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    if (displayName.isNotEmpty) {
      await _prefs.setString(_displayNameKey, displayName);
    }

    if (!AppConfig.useMockData) {
      try {
        await _api.patch(
          ApiPaths.me,
          data: {
            'firstName': ?firstName,
            'lastName': ?lastName,
            'avatarUrl': ?avatarUrl,
          },
        );
      } catch (_) {
        // No server-side profile-update endpoint yet.
      }
    }
  }

  /// Copies the picked image into app storage under a stable name, so the
  /// avatar survives the OS clearing the picker's temp file and a plain
  /// `getApplicationDocumentsDirectory` path keeps working across restarts.
  Future<String> _cacheAvatarLocally(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = source.path.contains('.') ? source.path.split('.').last : 'jpg';
    final target = await source.copy('${dir.path}/customer_avatar.$ext');
    return target.path;
  }

  Future<void> _refreshProfile() async {
    try {
      final response = await _api.get(ApiPaths.me);
      if (response.statusCode != 200) return;
      final user = response.data as Map<String, dynamic>;
      final displayName = [
        user['firstName'],
        user['lastName'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      if (displayName.isNotEmpty) {
        await _prefs.setString(_displayNameKey, displayName);
      }
    } catch (_) {
      // A cached profile lets the customer browse while temporarily offline.
    }
  }
}
