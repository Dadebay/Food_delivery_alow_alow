import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/data/ordering_hours_repository.dart';
import '../../core/models/ordering_hours.dart';

/// Whether the restaurant is taking orders, kept fresh for checkout.
///
/// Re-read on two occasions: when the customer opens checkout, and when the
/// app comes back from the background. The second matters because a phone
/// left on the checkout screen overnight would otherwise still be showing
/// yesterday's "open".
///
/// The phone's own clock is never consulted. [OrderingHours.isOpen] is the
/// server's verdict, and it already accounts for a window that crosses
/// midnight and for the restaurant's timezone rather than the device's.
class OrderingHoursProvider extends ChangeNotifier with WidgetsBindingObserver {
  OrderingHoursProvider({required OrderingHoursRepository repository})
    : _repository = repository {
    WidgetsBinding.instance.addObserver(this);
  }

  final OrderingHoursRepository _repository;

  /// Starts unrestricted: until the server says otherwise, the order button
  /// works. Defaulting to "closed" would lock out every customer on a
  /// server that has no such endpoint.
  OrderingHours _hours = OrderingHours.unrestricted;
  bool _loading = false;

  OrderingHours get hours => _hours;
  bool get loading => _loading;

  /// The one thing screens act on: true only when the server is enforcing
  /// hours *and* says it is shut right now.
  bool get blocksOrdering => _hours.blocksOrdering;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _hours = await _repository.hours();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
