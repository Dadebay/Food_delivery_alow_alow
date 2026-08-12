import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Holds the selected language and hands out the matching [AppStrings].
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs)
    : _strings = _prefs.getString(_key) == 'tk'
          ? const StringsTm()
          : const StringsRu();

  static const String _key = 'app_language';

  final SharedPreferences _prefs;
  AppStrings _strings;

  AppStrings get strings => _strings;
  Locale get locale => Locale(_strings.languageCode);

  /// Whether the customer has explicitly picked a language yet — distinct
  /// from [strings], which always has a default. Drives whether the
  /// stand-alone language screen shows on first launch (see `app.dart`).
  bool get hasChosen => _prefs.containsKey(_key);

  static const List<AppStrings> supported = [StringsRu(), StringsTm()];

  Future<void> select(AppStrings strings) async {
    _strings = strings;
    // Always persist, even re-picking the current default — that's what
    // turns "has a language" into "chose a language", and callers (e.g. the
    // stand-alone language screen) rely on the notify to move on regardless
    // of whether the value actually changed.
    await _prefs.setString(_key, strings.languageCode);
    notifyListeners();
  }
}

/// `context.s.addToCart` — short enough to use inline in a widget tree.
extension LocalizedContext on BuildContext {
  AppStrings get s => watch<LocaleProvider>().strings;

  /// Non-listening variant for callbacks (snackbars, dialogs).
  AppStrings get sr => read<LocaleProvider>().strings;
}
