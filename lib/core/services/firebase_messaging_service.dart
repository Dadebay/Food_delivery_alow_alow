import 'dart:async';
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

  /// Every install subscribes to this, so the backend can reach all
  /// customers with one publish instead of fanning out over stored tokens.
  /// The name is part of the contract with the backend: change it here and
  /// whoever publishes has to change it in the same breath, or the messages
  /// go to a topic nobody is listening on.
  ///
  /// Subscribed before any sign-in, and never dropped at sign-out: these are
  /// public announcements, and a guest is as much an audience for them as a
  /// signed-in customer.
  static const String broadcastTopic = 'a7-tagam';

  /// The name this app used before. Kept only so an install that upgrades can
  /// be taken off it — a device left on both topics receives every
  /// announcement twice for as long as the backend publishes to either.
  static const String _legacyBroadcastTopic = 'hantagam';

  /// The tab a tapped notification asked for, or null.
  ///
  /// A notifier rather than a direct jump: a tap can arrive before any widget
  /// exists — `getInitialMessage` fires while the app is still starting from
  /// terminated — so the destination is parked here and the shell acts on it
  /// once it is mounted. See `MainNavScreen`.
  final ValueNotifier<int?> pendingTab = ValueNotifier<int?>(null);

  /// Deep links this app is willing to follow, mapped to bottom-nav tabs.
  ///
  /// An allowlist, not a parser: `deepLink` arrives from a push payload, so
  /// anything not named here — an unknown screen, an `http://` address, a
  /// path with an id we cannot verify — is ignored and the customer simply
  /// lands on the home tab.
  static const Map<String, int> _deepLinkTabs = {
    '/': 0,
    '/home': 0,
    '/catalog': 1,
    '/categories': 1,
    '/cart': 2,
    '/orders': 3,
    '/profile': 4,
  };

  /// Campaigns already acted on, so one announcement opens one screen.
  ///
  /// A topic message carries no per-device id, and the backend warns that a
  /// system-tray delivery is not guaranteed exactly-once, so `campaignId` is
  /// the only stable key. In-memory on purpose: it exists to stop a double
  /// tap and a re-delivery inside one run, not to remember campaigns forever.
  final Set<String> _handledCampaigns = <String>{};

  String? _apnsToken;
  Future<String?>? _apnsWait;

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
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    // The tap that launched a terminated app is delivered here and nowhere
    // else — `onMessageOpenedApp` only ever fires for an app already running,
    // so without this a cold-start tap silently lands on the home screen.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleOpenedMessage(initial);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _debugToken('FCM TOKEN REFRESHED', token, '32');
      onTokenRefresh?.call();
      // On iOS this is also the moment a token first appears when Apple took
      // longer than the wait below allowed. Re-subscribing here is what turns
      // a skipped topic into a working one during this run instead of the
      // next launch; `subscribeToTopic` is idempotent, so the ordinary
      // rotation case costs nothing.
      unawaited(subscribeToBroadcastTopic());
    });

    await _printDeviceTokens();
    await subscribeToBroadcastTopic();
  }

  /// Subscribes this device to [broadcastTopic].
  ///
  /// Called on every start rather than once: the call is idempotent, so a
  /// launch that failed offline simply fixes itself on the next one. A
  /// failure is logged and swallowed — push is an extra, never a reason for
  /// start-up to stall.
  Future<void> subscribeToBroadcastTopic() async {
    // iOS refuses topic subscriptions until APNs has issued its own token;
    // Android has nothing to wait for.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _awaitApnsToken() == null) {
      _debugToken(
        'FCM TOPIC',
        'skipped: APNs token not issued yet, retrying on next launch',
        '33',
      );
      return;
    }

    try {
      await FirebaseMessaging.instance.subscribeToTopic(broadcastTopic);
      _debugToken('FCM TOPIC', 'subscribed to "$broadcastTopic"', '32');

      // Only after the new topic is genuinely subscribed — dropping the old
      // one first would leave an install that fails here on neither topic,
      // silently cut off from announcements until it next succeeds.
      await _leaveLegacyTopic();
    } catch (error, stackTrace) {
      developer.log(
        'Topic subscription failed; this device only receives pushes '
        'addressed to its own token until the next launch.',
        name: 'AlowAlow FCM',
        error: error,
        stackTrace: stackTrace,
      );
      _debugToken('FCM TOPIC', 'subscription failed: $error', '31');
    }
  }

  /// Test seam for the allowlist and the campaign de-duplication — the rest
  /// of this class needs a live Firebase, these two rules do not.
  @visibleForTesting
  void debugHandleOpenedMessage(RemoteMessage message) =>
      _resolveDestination(message);

  @visibleForTesting
  void debugClearHandledCampaigns() => _handledCampaigns.clear();

  /// A notification the customer tapped, from any app state.
  void _handleOpenedMessage(RemoteMessage message) {
    AnalyticsService.instance.notificationOpened(message);
    _resolveDestination(message);
  }

  void _resolveDestination(RemoteMessage message) {
    final campaignId = _dataString(message.data, 'campaignId');
    if (campaignId != null && !_handledCampaigns.add(campaignId)) {
      developer.log(
        'Campaign $campaignId already opened this run; ignoring the repeat.',
        name: 'AlowAlow FCM',
      );
      return;
    }

    final tab = _deepLinkTabs[_dataString(message.data, 'deepLink')];
    if (tab == null) return;
    pendingTab.value = tab;
  }

  /// Takes an upgraded install off the topic this app used to listen on.
  ///
  /// Runs on every launch rather than once: it is idempotent, and a flag
  /// stored on the device would have to survive a reinstall to be worth more
  /// than simply asking again. A failure is not worth reporting loudly — the
  /// worst case is a duplicate announcement, which the next launch fixes.
  Future<void> _leaveLegacyTopic() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(
        _legacyBroadcastTopic,
      );
    } catch (error) {
      developer.log(
        'Could not leave "$_legacyBroadcastTopic"; this device may receive '
        'one announcement twice until the next launch: $error',
        name: 'AlowAlow FCM',
      );
    }
  }

  /// The FCM registration token, or null when this device has none yet.
  ///
  /// On iOS `getToken()` does not return null while the APNs token is
  /// missing — it throws `apns-token-not-set`. Every caller wants "no token
  /// yet" rather than an exception, so the APNs wait happens first and a
  /// failure is reported as null.
  Future<String?> deviceToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _awaitApnsToken() == null) {
      return null;
    }
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error, stackTrace) {
      developer.log(
        'Unable to obtain FCM token',
        name: 'AlowAlow FCM',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// iOS issues the APNs token slightly after the permission dialog, and FCM
  /// refuses both `getToken()` and a topic subscription until it exists.
  ///
  /// The wait is shared and its result cached: the token print, the topic
  /// subscription and the device registration all run at start-up, and three
  /// independent waits would stack up on exactly the launch that is already
  /// slow. It is also bounded — a simulator never receives an APNs token at
  /// all, and the app has to carry on without push rather than stall.
  Future<String?> _awaitApnsToken() {
    final cached = _apnsToken;
    if (cached != null) return Future<String?>.value(cached);
    return _apnsWait ??= _pollApnsToken();
  }

  Future<String?> _pollApnsToken() async {
    // Apple can take several seconds on a cold install or a weak connection;
    // the previous three attempts routinely expired before the token landed.
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null) return _apnsToken = token;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // Cleared so a later caller — the `onTokenRefresh` listener, once Apple
    // finally delivers — starts a fresh wait instead of being handed this
    // expired one.
    _apnsWait = null;
    return null;
  }

  Future<void> _printDeviceTokens() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _awaitApnsToken();
      _debugToken(
        'APNS TOKEN',
        apnsToken ??
            'not available yet (use a physical iPhone and enable Push Notifications)',
        apnsToken == null ? '33' : '35',
      );
    } else {
      _debugToken('APNS TOKEN', 'iOS devices only', '33');
    }

    final fcmToken = await deviceToken();
    _debugToken(
      'FCM TOKEN',
      fcmToken ?? 'not available yet',
      fcmToken == null ? '33' : '32',
    );
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
