import 'dart:developer' as dev;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Reminds the customer about a cart they walked away from.
///
/// One notification, once a day, at dinner time — not the moment they leave
/// the app. A basket abandoned at three in the afternoon is not a decision
/// the customer wants argued with straight away; the same basket at seven in
/// the evening is a useful question.
///
/// Scheduled on the device rather than sent from the server: the cart never
/// leaves the phone, so the server has nothing to remind anyone about, and a
/// local notification keeps working with no connection at all.
class CartReminderService {
  CartReminderService._();

  static final instance = CartReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 19:00 — after work, before the evening is over. The reminder is about
  /// dinner, so it has to arrive while dinner is still a choice.
  static const int _hour = 19;

  /// Its own id, so rescheduling replaces the pending one instead of
  /// stacking a second.
  static const int _notificationId = 8801;

  static const _channel = AndroidNotificationChannel(
    'alowalow_cart',
    'Cart reminders',
    description: 'A daily reminder about dishes left in the basket',
    // Deliberately below the order channel: this is a nudge, not news about
    // an order already placed.
    importance: Importance.defaultImportance,
  );

  /// Delivery happens in Ashgabat, so the reminder is anchored to Ashgabat's
  /// evening rather than the phone's.
  ///
  /// This is not a detail that can be skipped: `initializeTimeZones` only
  /// loads the database, it does not pick a zone, and `tz.local` stays UTC
  /// until told otherwise. Left at UTC, "19:00" would have arrived at
  /// midnight local time — a reminder about dinner, delivered after the
  /// kitchen closed.
  static const String _zone = 'Asia/Ashgabat';

  Future<void> initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_zone));
    // The plugin is a singleton and FirebaseMessagingService already
    // initialises it at startup, including the iOS settings. Doing it again
    // is harmless and means this service still works if that order ever
    // changes.
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
    _ready = true;
  }

  /// Books tomorrow's reminder — or today's, if dinner has not passed yet.
  ///
  /// Call it whenever the cart changes: each call replaces the pending one,
  /// so the text always names what is actually in the basket now.
  Future<void> schedule({required String title, required String body}) async {
    try {
      await initialize();
      await _plugin.zonedSchedule(
        _notificationId,
        title,
        body,
        _nextMealTime(),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeats at the same hour every day for as long as the cart stands.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      // A refused permission or an OEM that blocks scheduling must not take
      // the cart down with it — the reminder is a courtesy.
      dev.log('cart reminder not scheduled: $error', name: 'CartReminder');
    }
  }

  /// The basket is empty or the order is placed: there is nothing to ask
  /// about any more.
  Future<void> cancel() async {
    try {
      await initialize();
      await _plugin.cancel(_notificationId);
    } catch (error) {
      dev.log('cart reminder not cancelled: $error', name: 'CartReminder');
    }
  }

  tz.TZDateTime _nextMealTime() {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, _hour);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }
}
