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

    // iOS routes *every* foreground notification through firebase_messaging's
    // UNUserNotificationCenter delegate — including the local ones we post
    // ourselves, which carry no `gcm.message_id`. That delegate answers with
    // whatever is persisted here, so leaving these at their `false` default
    // suppresses our own local notifications too. Keeping them true is what
    // makes anything appear at all while the app is open.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        _dataString(message.data, 'title') ??
        'Sargyt täzelendi';
    final body =
        notification?.body ??
        _dataString(message.data, 'body') ??
        _dataString(message.data, 'message') ??
        'Sargydyňyzyň ýagdaýy üýtgedi.';

    if (kDebugMode) {
      const cyan = '\x1B[1;36m';
      const yellow = '\x1B[1;33m';
      const reset = '\x1B[0m';
      debugPrint('$cyan╔════════ FCM FOREGROUND RECEIVED ════════╗$reset');
      debugPrint('$cyan║$reset TITLE: $yellow$title$reset');
      debugPrint('$cyan║$reset BODY: $body');
      debugPrint('$cyan║$reset DATA: ${message.data}');
      debugPrint('$cyan╚═════════════════════════════════════════╝$reset');
    }
    // Android never displays a foreground push on its own, so we always post
    // one. iOS already presented the alert natively by the time this runs
    // (see setForegroundNotificationPresentationOptions), so posting again
    // there would show the same thing twice — unless the payload was
    // data-only, in which case iOS showed nothing and it is on us.
    final iosAlreadyShown =
        defaultTargetPlatform == TargetPlatform.iOS && notification != null;
    if (iosAlreadyShown) return;

    await LocalNotificationsService.instance.show(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }

  String? _dataString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty ? value : null;
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
