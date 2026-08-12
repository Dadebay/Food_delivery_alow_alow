import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/catalog_repository.dart';
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

  List<DishCategory> _categories = const [];
  List<Dish> _dishes = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  final Random _homeRandom = Random();
  List<String> _homeCategoryIds = const [];
  Map<String, List<Dish>> _homeDishes = const {};

  List<DishCategory> get categories => _categories;
  List<Dish> get dishes => _dishes;
  bool get loading => _loading;
  Object? get error => _error;
  String get query => _query;

  /// A welcoming home feed feels fresher when its category shelves and the
  /// dishes inside them are re-dealt once for every app session. Catalogue
  /// editing and category-specific screens retain their normal stable order.
  List<DishCategory> get homeCategories => _homeCategoryIds
      .map((id) => _categories.where((category) => category.id == id).first)
      .toList(growable: false);

  List<Dish> homeDishesForCategory(String categoryId) =>
      _homeDishes[categoryId] ?? const [];

  List<Dish> get favorites => _dishes.where((d) => d.isFavorite).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // The server has no "all products" call — categoryId is required —
      // so categories load first, then every category's dishes load in
      // parallel off that list, rather than each fetching categories again.
      final categories = await _repository.categories();
      final perCategory = await Future.wait(
        categories.map(
          (category) => _repository.dishesForCategory(category.id),
        ),
      );
      _categories = categories;
      _dishes = perCategory.expand((dishes) => dishes).toList();
      _applyFavorites();
      _randomizeHomeMenu();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
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
    _homeCategoryIds = categories.map((category) => category.id).toList();
    _homeDishes = {
      for (final category in categories)
        category.id: (List<Dish>.from(
          _dishes.where((dish) => dish.categoryId == category.id),
        )..shuffle(_homeRandom)),
    };
  }
}
