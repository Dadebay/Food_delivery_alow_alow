import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a visible notification while the app is in the foreground.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final instance = LocalNotificationsService._();
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'alowalow_orders',
    'Order notifications',
    description: 'Order updates and delivery notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  Future<void> show({String? title, String? body, String? payload}) {
    return _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alowalow_orders',
          'Order notifications',
          channelDescription: 'Order updates and delivery notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
