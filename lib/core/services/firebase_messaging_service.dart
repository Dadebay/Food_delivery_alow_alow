import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'local_notifications_service.dart';

/// Requests notification permission, receives push messages, and prints the
/// device tokens in a clearly visible form while running in debug mode.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final instance = FirebaseMessagingService._();

  /// [onTokenRefresh] re-sends the token to our backend whenever FCM
  /// rotates it — a token registered once and never updated is exactly how
  /// a device silently stops receiving pushes.
  Future<void> initialize({VoidCallback? onTokenRefresh}) async {
    await LocalNotificationsService.instance.initialize();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _debugToken(
      'NOTIFICATION PERMISSION',
      settings.authorizationStatus.name,
      '36',
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AnalyticsService.instance.notificationOpened(message);
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _debugToken('FCM TOKEN REFRESHED', token, '32');
      onTokenRefresh?.call();
    });

    await _printDeviceTokens();
  }

  Future<void> _printDeviceTokens() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // APNs registration can finish slightly after the permission dialog.
      String? apnsToken;
      for (var attempt = 0; attempt < 3 && apnsToken == null; attempt++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _debugToken(
        'APNS TOKEN',
        apnsToken ??
            'not available yet (use a physical iPhone and enable Push Notifications)',
        apnsToken == null ? '33' : '35',
      );
    } else {
      _debugToken('APNS TOKEN', 'iOS devices only', '33');
    }

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      _debugToken(
        'FCM TOKEN',
        fcmToken ?? 'not available yet',
        fcmToken == null ? '33' : '32',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Unable to obtain FCM token',
        name: 'AlowAlow FCM',
        error: error,
        stackTrace: stackTrace,
      );
      _debugToken('FCM TOKEN', 'unavailable: $error', '31');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      LocalNotificationsService.instance.show(
        title: notification.title,
        body: notification.body,
        payload: message.data.toString(),
      );
    }
  }

  void _debugToken(String label, String value, String ansiColor) {
    if (!kDebugMode) return;
    developer.log('$label: $value', name: 'AlowAlow FCM');
    // ANSI escapes are displayed in colour by terminals used with `flutter run`.
    // ignore: avoid_print
    print('\x1B[1;${ansiColor}m╔══ ALOWALOW $label ══╗\x1B[0m');
    // ignore: avoid_print
    print('\x1B[${ansiColor}m$value\x1B[0m');
    // ignore: avoid_print
    print('\x1B[1;${ansiColor}m╚════════════════════════════════╝\x1B[0m');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  developer.log(
    'Background message: ${message.messageId}',
    name: 'AlowAlow FCM',
  );
}
