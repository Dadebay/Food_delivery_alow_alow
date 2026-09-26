import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/services/app_update_service.dart';
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
  AppUpdateService? _appUpdate;
  bool _updatePromptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A cold start from a tapped notification resolves its destination
      // before this screen exists, so the parked value is read once here as
      // well as watched for later taps.
      _openPendingTab();
    });
    _push.pendingTab.addListener(_openPendingTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final update = context.read<AppUpdateService>();
    if (identical(update, _appUpdate)) return;
    _appUpdate?.removeListener(_scheduleUpdatePrompt);
    _appUpdate = update..addListener(_scheduleUpdatePrompt);
    _scheduleUpdatePrompt();
  }

  @override
  void dispose() {
    _appUpdate?.removeListener(_scheduleUpdatePrompt);
    _push.pendingTab.removeListener(_openPendingTab);
    super.dispose();
  }

  /// Store lookups usually finish after the first frame. Listening to the
  /// service prevents that late answer from being missed, while the flag
  /// prevents rebuilds from scheduling the same modal more than once.
  void _scheduleUpdatePrompt() {
    if (!mounted ||
        _updatePromptScheduled ||
        !(_appUpdate?.shouldPromptOptional ?? false)) {
      return;
    }
    _updatePromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showOptionalUpdateSheet(context);
      _updatePromptScheduled = false;
    });
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
