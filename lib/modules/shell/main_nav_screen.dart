import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/services/firebase_messaging_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/cart_fly_animation.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../category/category_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../update/optional_update_sheet.dart';
import 'animated_bottom_nav_bar.dart';
import 'tab_switcher.dart';

/// The five tabs: Главная, Блюда, Sebet, Заказы, Профиль. Favourites moved
/// off the bar into the profile screen — it's a personal list, not a way to
/// browse the menu, and Category needed the slot to give browsing by section
/// its own dedicated tab instead of just the chips on home. An [IndexedStack]
/// keeps each tab's scroll position and state alive when switching, rather
/// than rebuilding from scratch every time.
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  static const _screens = [
    HomeScreen(),
    CategoryScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  final _push = FirebaseMessagingService.instance;

  @override
  void initState() {
    super.initState();
    // After the first frame: the version check runs in the background from
    // `main`, so its answer usually lands around now rather than before the
    // menu is on screen. Nothing happens unless there is something to offer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showOptionalUpdateSheet(context);
      // A cold start from a tapped notification resolves its destination
      // before this screen exists, so the parked value is read once here as
      // well as watched for later taps.
      _openPendingTab();
    });
    _push.pendingTab.addListener(_openPendingTab);
  }

  @override
  void dispose() {
    _push.pendingTab.removeListener(_openPendingTab);
    super.dispose();
  }

  void _openPendingTab() {
    final tab = _push.pendingTab.value;
    if (tab == null || !mounted) return;
    // Cleared as it is consumed, so returning to this screen later does not
    // replay a notification the customer already followed.
    _push.pendingTab.value = null;
    context.read<TabSwitcher>().go(tab);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cartCount = context.watch<CartProvider>().itemCount;
    final index = context.watch<TabSwitcher>().index;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Image.asset(
              'assets/images/app_food_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          IndexedStack(index: index, children: _screens),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: index,
        onTap: (i) => context.read<TabSwitcher>().go(i),
        items: [
          NavBarItemData(icon: AppIcons.home, label: s.navHome),
          NavBarItemData(icon: AppIcons.category, label: s.sections),
          NavBarItemData(
            icon: AppIcons.cart,
            label: s.navCart,
            badgeCount: cartCount,
            iconKey: CartFlyAnimation.cartIconKey,
          ),
          NavBarItemData(icon: AppIcons.orders, label: s.navOrders),
          NavBarItemData(icon: AppIcons.user, label: s.navProfile),
        ],
      ),
    );
  }
}
