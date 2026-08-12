import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// The API targets the FCM registration token, not the Firebase Installation
/// ID — targeting by installation ID (`fid`) consistently came back
/// `messaging/installation-id-not-registered` from FCM even for a
/// freshly-generated ID with a live token behind it, confirmed against real
/// devices. The token is the long-standing, universally supported way to
/// reach one device, so this sends it under the same `installationId` field
/// the API already exposes rather than adding a second, redundant one.
class PushDeviceRegistrationService {
  PushDeviceRegistrationService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<void> register() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        developer.log(
          'No FCM token available yet; skipping push registration.',
          name: 'AlowAlow Push',
        );
        return;
      }
      final response = await _api.put(
        ApiPaths.pushDevices,
        data: {
          'installationId': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
      );
      if (response.statusCode == null || response.statusCode! >= 300) {
        throw StateError('API returned ${response.statusCode}');
      }
      developer.log('Push device registered', name: 'AlowAlow Push');
    } catch (error, stackTrace) {
      developer.log(
        'Push device registration failed; sign-in remains available.',
        name: 'AlowAlow Push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _api.delete(ApiPaths.pushDevice(token));
    } catch (error, stackTrace) {
      developer.log(
        'Push device deactivation failed.',
        name: 'AlowAlow Push',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
