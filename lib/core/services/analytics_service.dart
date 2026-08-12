import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/cart_item.dart';
import '../models/dish.dart';
import '../models/order.dart';

/// Central, privacy-conscious event vocabulary for menu and order behaviour.
class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  Future<void> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return Future.value();
    return analytics.logSearch(searchTerm: normalized);
  }

  Future<void> screen(String name) => analytics.logScreenView(screenName: name);

  Future<void> categorySelected(String? categoryId) => analytics.logEvent(
    name: 'category_selected',
    parameters: {'category_id': categoryId ?? 'all'},
  );

  Future<void> dishOpened(Dish dish) => analytics.logEvent(
    name: 'dish_opened',
    parameters: {
      'dish_id': dish.id,
      'dish_name': dish.name,
      'category_id': dish.categoryId,
    },
  );

  Future<void> addedToCart(Dish dish, int quantity) => analytics.logAddToCart(
    currency: 'TMT',
    value: dish.discountedPrice * quantity,
    items: [_item(dish, quantity)],
  );

  Future<void> checkoutStarted(List<CartItem> items, double total) =>
      analytics.logBeginCheckout(
        currency: 'TMT',
        value: total,
        items: items.map((item) => _item(item.dish, item.quantity)).toList(),
      );

  Future<void> orderPlaced(CustomerOrder order) async {
    await analytics.logPurchase(
      currency: 'TMT',
      value: order.total,
      shipping: order.deliveryFee,
      transactionId: order.id,
      items: order.items
          .map((item) => _item(item.dish, item.quantity))
          .toList(),
    );
    await analytics.logEvent(
      name: 'order_placed',
      parameters: {
        'order_id': order.id,
        'item_count': order.itemCount,
        'order_hour': order.placedAt.hour,
        'order_weekday': order.placedAt.weekday,
      },
    );
  }

  Future<void> notificationOpened(RemoteMessage message) => analytics.logEvent(
    name: 'notification_opened',
    parameters: {
      if (message.messageId != null) 'message_id': message.messageId!,
      if (message.data['type'] != null)
        'notification_type': message.data['type'].toString(),
    },
  );

  AnalyticsEventItem _item(Dish dish, int quantity) => AnalyticsEventItem(
    itemId: dish.id,
    itemName: dish.name,
    itemCategory: dish.categoryId,
    currency: 'TMT',
    price: dish.discountedPrice,
    quantity: quantity,
  );
}
