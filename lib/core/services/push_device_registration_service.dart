import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'firebase_messaging_service.dart';

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
    // A guest has no JWT, and this endpoint is customer-only: calling it
    // would spend a request to earn a 401. Guests still receive the public
    // broadcast topic, which needs no registration at all — sign-in is what
    // brings the personal channel with it, and `AuthRepository` calls this
    // again at that moment.
    if (!_api.hasToken) {
      developer.log(
        'Not signed in; skipping push device registration.',
        name: 'AlowAlow Push',
      );
      return;
    }

    try {
      // Goes through the messaging service rather than FCM directly: on iOS
      // `getToken()` throws until Apple has issued the APNs token, and that
      // wait — plus the "no token yet" answer this needs — lives there.
      // Registration then happens on its own through `onTokenRefresh`, which
      // fires the moment the token does arrive.
      final token = await FirebaseMessagingService.instance.deviceToken();
      if (token == null) {
        developer.log(
          'No FCM token available yet; push registration will retry once the '
          'token is issued.',
          name: 'AlowAlow Push',
        );
        return;
      }
      final response = await _api.put(
        ApiPaths.pushDevices,
        // Registering for notifications is not worth a session. If this 401s
        // the app keeps quiet and tries again next launch.
        bestEffort: true,
        data: {
          'installationId': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
      );
      if (response.statusCode == null || response.statusCode! >= 300) {
        // The status alone never said *why*. The guard rejects a token for
        // three different reasons and names each one in the body; without it
        // a 401 here is indistinguishable from a revoked session.
        final body = response.data;
        final reason = body is Map && body['message'] != null
            ? body['message']
            : body;
        throw StateError('API returned ${response.statusCode} — $reason');
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
      final token = await FirebaseMessagingService.instance.deviceToken();
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
