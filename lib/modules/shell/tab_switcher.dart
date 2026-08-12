import 'package:flutter/foundation.dart';

import '../../core/services/analytics_service.dart';

/// Lets any screen jump to a different bottom-nav tab — e.g. the cart bar at
/// the bottom of the home screen switching straight to the cart tab, without
/// pushing a new route on top of it.
class TabSwitcher extends ChangeNotifier {
  static const _screenNames = [
    'home',
    'categories',
    'cart',
    'orders',
    'profile',
  ];
  int _index = 0;

  int get index => _index;

  void go(int index) {
    if (_index == index) return;
    _index = index;
    if (index >= 0 && index < _screenNames.length) {
      AnalyticsService.instance.screen(_screenNames[index]);
    }
    notifyListeners();
  }
}
