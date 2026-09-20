import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/services/firebase_messaging_service.dart';

/// `deepLink` arrives inside a push payload, so it is untrusted input. These
/// cover the allowlist rather than the Firebase plumbing.
void main() {
  final service = FirebaseMessagingService.instance;

  RemoteMessage message(Map<String, String> data) =>
      RemoteMessage(data: data, messageId: 'm-${data['campaignId'] ?? '0'}');

  setUp(() {
    service.pendingTab.value = null;
    service.debugClearHandledCampaigns();
  });

  test('a known deep link selects its tab', () {
    service.debugHandleOpenedMessage(
      message({'campaignId': 'c1', 'deepLink': '/catalog'}),
    );
    expect(service.pendingTab.value, 1);
  });

  test('an unknown screen is ignored and nothing is opened', () {
    service.debugHandleOpenedMessage(
      message({'campaignId': 'c2', 'deepLink': '/admin/secrets'}),
    );
    expect(service.pendingTab.value, isNull);
  });

  test('an external address is never followed', () {
    for (final hostile in const [
      'https://evil.example/pay',
      'http://a7-tagam.com.tm/catalog',
      'javascript:alert(1)',
      '//evil.example',
    ]) {
      service.debugClearHandledCampaigns();
      service.pendingTab.value = null;
      service.debugHandleOpenedMessage(
        message({'campaignId': 'c3', 'deepLink': hostile}),
      );
      expect(
        service.pendingTab.value,
        isNull,
        reason: '$hostile must not resolve to a tab',
      );
    }
  });

  test('a message with no deep link opens nothing', () {
    service.debugHandleOpenedMessage(message({'campaignId': 'c4'}));
    expect(service.pendingTab.value, isNull);
  });

  test('the same campaign only acts once', () {
    service.debugHandleOpenedMessage(
      message({'campaignId': 'dup', 'deepLink': '/orders'}),
    );
    expect(service.pendingTab.value, 3);

    // The shell consumes the value; a re-delivery of the same campaign must
    // not drag the customer back to that tab a second time.
    service.pendingTab.value = null;
    service.debugHandleOpenedMessage(
      message({'campaignId': 'dup', 'deepLink': '/orders'}),
    );
    expect(service.pendingTab.value, isNull);
  });

  test('different campaigns each get their turn', () {
    service.debugHandleOpenedMessage(
      message({'campaignId': 'a', 'deepLink': '/cart'}),
    );
    expect(service.pendingTab.value, 2);

    service.pendingTab.value = null;
    service.debugHandleOpenedMessage(
      message({'campaignId': 'b', 'deepLink': '/profile'}),
    );
    expect(service.pendingTab.value, 4);
  });
}
