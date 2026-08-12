import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the customer has already been through the intro screens — shown
/// once on first launch, never again after that (browsing itself never
/// requires an account, so this is purely a one-time welcome, not a gate).
class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this._prefs);

  static const String _key = 'onboarding_seen';

  final SharedPreferences _prefs;

  bool get seen => _prefs.getBool(_key) ?? false;

  Future<void> complete() async {
    await _prefs.setBool(_key, true);
    notifyListeners();
  }
}
