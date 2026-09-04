import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/delivery_loader.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_provider.dart';
import '../shell/tab_switcher.dart';
import 'order_detail_screen.dart';
import 'order_provider.dart';
import 'widgets/order_history_card.dart';

/// Orders tab — history and the reorder shortcut (proposal slide 5:
/// "история заказов и повтор в одно касание"). Order history belongs to an
/// account, so this is one of the two tabs (with Profile) that asks for
/// sign-in — browsing and the cart never do.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _loadTriggered = false;

  void _reorder(CustomerOrder order) {
    final cart = context.read<CartProvider>();
    for (final item in order.items) {
      cart.add(
        item.dish,
        variant: item.variant,
        quantity: item.quantity,
        note: item.note,
      );
    }
    context.read<TabSwitcher>().go(2);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();

    if (!auth.isSignedIn) {
      // Reset so history loads fresh the moment they do sign in — including
      // if they signed in from a different tab (Profile) while this one sat
      // idle in the background.
      _loadTriggered = false;
      return Scaffold(
        // A slightly off-white backdrop so the white order cards actually
        // read as raised cards instead of blending into an identical
        // background.
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.ordersTitle),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppColors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _SignInPrompt(
          title: s.ordersEmpty,
          hint: s.signInPromptOrders,
          label: s.signIn,
        ),
      );
    }

    if (!_loadTriggered) {
      _loadTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => orders.load());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(s.ordersTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: orders.loading
          ? ColoredBox(
              color: AppColors.loaderBackground,
              child: Center(
                child: DeliveryLoader(size: 200, message: s.loadingHint),
              ),
            )
          : orders.orders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/empty_order.png',
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        semanticLabel: s.ordersEmpty,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(s.ordersEmpty, style: AppText.h2),
                    const SizedBox(height: 8),
                    Text(
                      s.ordersEmptyHint,
                      textAlign: TextAlign.center,
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.green,
              onRefresh: orders.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: orders.orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = orders.orders[index];
                  return OrderHistoryCard(
                    order: order,
                    strings: s,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: order.id),
                      ),
                    ),
                    onReorder: () => _reorder(order),
                  );
                },
              ),
            ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({
    required this.title,
    required this.hint,
    required this.label,
  });

  final String title;
  final String hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/empty_order.png',
                width: 250,
                height: 250,
                fit: BoxFit.cover,
                semanticLabel: title,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppText.h2),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center, style: AppText.bodyMuted),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: AppButton(
                label: label,
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
