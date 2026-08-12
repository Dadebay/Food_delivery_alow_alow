import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/data/order_repository.dart';
import 'package:food_delivery/core/localization/locale_provider.dart';
import 'package:food_delivery/core/network/api_client.dart';
import 'package:food_delivery/modules/orders/order_detail_screen.dart';
import 'package:food_delivery/modules/orders/order_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('order detail screen renders each seeded order without overflow', (tester) async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final orderProvider = OrderProvider(repository: OrderRepository(api: ApiClient()));
    await orderProvider.load();

    for (final order in orderProvider.orders) {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
            ChangeNotifierProvider.value(value: orderProvider),
          ],
          child: MaterialApp(home: OrderDetailScreen(orderId: order.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'order ${order.id} (${order.status})');
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    }
  });
}
