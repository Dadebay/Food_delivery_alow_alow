import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_icons.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../category/category_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import 'animated_bottom_nav_bar.dart';
import 'tab_switcher.dart';

/// The five tabs: Главная, Блюда, Sebet, Заказы, Профиль. Favourites moved
/// off the bar into the profile screen — it's a personal list, not a way to
/// browse the menu, and Category needed the slot to give browsing by section
/// its own dedicated tab instead of just the chips on home. An [IndexedStack]
/// keeps each tab's scroll position and state alive when switching, rather
/// than rebuilding from scratch every time.
class MainNavScreen extends StatelessWidget {
  const MainNavScreen({super.key});

  static const _screens = [
    HomeScreen(),
    CategoryScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cartCount = context.watch<CartProvider>().itemCount;
    final index = context.watch<TabSwitcher>().index;

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
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
          ),
          NavBarItemData(icon: AppIcons.orders, label: s.navOrders),
          NavBarItemData(icon: AppIcons.user, label: s.navProfile),
        ],
      ),
    );
  }
}
