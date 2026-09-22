import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/catalog_repository.dart';
import '../../core/models/cafe.dart';
import '../../core/models/dish.dart';

/// The menu: categories, dishes, and which ones are favorited.
///
/// One list of [Dish] objects is the single source of truth for the whole
/// app — the home grid, the favorites tab and the cart all point at the same
/// instances, so toggling a heart anywhere updates it everywhere at once.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({
    required CatalogRepository repository,
    required SharedPreferences prefs,
  }) : _repository = repository,
       _prefs = prefs;

  static const String _favoritesKey = 'favorite_dish_ids';

  final CatalogRepository _repository;
  final SharedPreferences _prefs;

  List<Cafe> _cafes = const [];
  String? _selectedCafeId;
  bool _switchingCafe = false;
  List<DishCategory> _categories = const [];
  List<Dish> _dishes = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  final Random _homeRandom = Random();
  List<DishCategory> _homeCategories = const [];
  Map<String, List<Dish>> _homeDishes = const {};

  /// The cafes to show in the selector, already in the order they belong in.
  List<Cafe> get cafes => _cafes;

  /// True while a newly picked cafe's menu is loading.
  ///
  /// Kept apart from [loading] because the two want different screens: a
  /// cold start may replace the whole page with a skeleton, but a cafe switch
  /// must leave the selector in place — the customer has to see which cafe
  /// they landed on, and be able to change their mind straight away.
  bool get switchingCafe => _switchingCafe;

  /// Which cafe's menu is on screen. Null only before the first load, or when
  /// the backend returned no cafes at all — then the legacy combined
  /// catalogue is shown instead.
  String? get selectedCafeId => _selectedCafeId;

  List<DishCategory> get categories => _categories;
  List<Dish> get dishes => _dishes;
  bool get loading => _loading;
  Object? get error => _error;
  String get query => _query;

  /// A welcoming home feed feels fresher when its category shelves and the
  /// dishes inside them are re-dealt once for every app session. Catalogue
  /// editing and category-specific screens retain their normal stable order.
  ///
  /// Stored pre-shuffled rather than as ids resolved on every read: the home
  /// feed re-reads this once per shelf as it scrolls into view, and looking
  /// each id back up in `_categories` on every one of those reads was a
  /// linear scan repeated for every scroll tick.
  List<DishCategory> get homeCategories => _homeCategories;

  List<Dish> homeDishesForCategory(String categoryId) =>
      _homeDishes[categoryId] ?? const [];

  List<Dish> get favorites => _dishes.where((d) => d.isFavorite).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // The cafe list decides what the rest of this load asks for, so it goes
      // first. A backend without cafes — or one that fails to answer this
      // one call — falls through to the combined catalogue rather than
      // leaving the customer with an empty screen.
      _cafes = await _safeCafes();
      _selectedCafeId = _cafes.isEmpty ? null : _cafes.first.id;
      notifyListeners();

      await _loadMenu();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Swaps the visible menu to another cafe.
  ///
  /// Deliberately leaves the cart alone: a cafe is display and navigation
  /// metadata, and an order may carry products from several of them. The
  /// backend validates every line and routes the whole order to one branch.
  Future<void> selectCafe(String cafeId) async {
    if (cafeId == _selectedCafeId) return;
    _selectedCafeId = cafeId;
    _loading = true;
    _switchingCafe = true;
    _error = null;
    // Clear the old cafe's menu straight away — leaving it on screen under a
    // freshly highlighted card reads as the tap having done nothing.
    _categories = const [];
    _dishes = const [];
    _homeCategories = const [];
    _homeDishes = const {};
    notifyListeners();
    try {
      await _loadMenu();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      _switchingCafe = false;
      notifyListeners();
    }
  }

  /// Re-reads the cafe list and the current menu.
  ///
  /// Called when the server rejects a quote or an order: that rejection is
  /// authoritative and usually means a cafe or product was hidden while the
  /// customer was browsing, so the cached screen is out of date.
  Future<void> refreshCatalog() async {
    final previous = _selectedCafeId;
    _cafes = await _safeCafes();
    // Keep the customer where they were unless that cafe is gone.
    final stillThere = _cafes.any((cafe) => cafe.id == previous);
    _selectedCafeId = stillThere
        ? previous
        : (_cafes.isEmpty ? null : _cafes.first.id);
    try {
      await _loadMenu();
    } catch (error) {
      _error = error;
    }
    notifyListeners();
  }

  /// Categories first, then products — the chips stop being a blank skeleton
  /// while the much larger product list is still in flight.
  Future<void> _loadMenu() async {
    _categories = await _repository.categories(cafeId: _selectedCafeId);
    notifyListeners();

    _dishes = await _repository.dishes(cafeId: _selectedCafeId);
    _applyFavorites();
    _randomizeHomeMenu();
  }

  /// A cafe list that fails to load is not a failed catalogue: the endpoint
  /// is new, and a client that cannot reach it should still get the legacy
  /// combined menu rather than an error screen.
  Future<List<Cafe>> _safeCafes() async {
    try {
      return await _repository.cafes();
    } catch (_) {
      return const [];
    }
  }

  /// Dishes for one category chip, or everything when [categoryId] is null
  /// ("Все"). `'popular'` is a virtual category — there is no such column on
  /// the dish, it just means "has a discount right now".
  List<Dish> forCategory(String? categoryId) {
    var list = _dishes;
    if (categoryId == 'popular') {
      list = list.where((d) => d.hasDiscount).toList();
    } else if (categoryId != null) {
      list = list.where((d) => d.categoryId == categoryId).toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((d) => d.name.toLowerCase().contains(q)).toList();
  }

  void search(String query) {
    _query = query.trim();
    notifyListeners();
  }

  Future<void> toggleFavorite(Dish dish) async {
    dish.isFavorite = !dish.isFavorite;
    notifyListeners();
    try {
      await _repository.setFavorite(dish.id, dish.isFavorite);
      await _saveFavorites();
    } catch (_) {
      dish.isFavorite = !dish.isFavorite;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> syncFavorites() async {
    try {
      final ids = await _repository.favoriteIds();
      for (final dish in _dishes) {
        dish.isFavorite = ids.contains(dish.id);
      }
      await _saveFavorites();
      notifyListeners();
    } catch (_) {
      // Browsing is public; a signed-out customer keeps local favorites.
    }
  }

  void _applyFavorites() {
    final saved =
        _prefs.getStringList(_favoritesKey)?.toSet() ?? const <String>{};
    for (final dish in _dishes) {
      dish.isFavorite = saved.contains(dish.id) || dish.isFavorite;
    }
  }

  Future<void> _saveFavorites() => _prefs.setStringList(
    _favoritesKey,
    _dishes.where((dish) => dish.isFavorite).map((dish) => dish.id).toList(),
  );

  void _randomizeHomeMenu() {
    final categories =
        _categories
            .where(
              (category) =>
                  _dishes.any((dish) => dish.categoryId == category.id),
            )
            .toList()
          ..shuffle(_homeRandom);
    _homeCategories = categories;
    _homeDishes = {
      for (final category in categories)
        category.id: (List<Dish>.from(
          _dishes.where((dish) => dish.categoryId == category.id),
        )..shuffle(_homeRandom)),
    };
  }
}
