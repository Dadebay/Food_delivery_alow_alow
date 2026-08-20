import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/dish.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/widgets/dish_grid.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../category/category_dishes_screen.dart';
import '../catalog/catalog_provider.dart';
import '../checkout/address_picker_screen.dart';
import '../checkout/address_provider.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/home_loading_skeleton.dart';
import 'banner_provider.dart';

/// Home tab — address header, search, promo banner, category chips, dish
/// grid. Matches `cust_home.png`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _category;
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.dishes.isEmpty) catalog.load();
      context.read<BannerProvider>().load();
      final addresses = context.read<AddressProvider>();
      if (addresses.address == null) addresses.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String query) {
    context.read<CatalogProvider>().search(query);
    _searchDebounce?.cancel();
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    // The category chips are hidden while searching, so a category picked
    // before the search started would otherwise silently keep narrowing
    // results the customer can no longer see or change.
    if (_category != null) setState(() => _category = null);
    _searchDebounce = Timer(const Duration(milliseconds: 700), () {
      AnalyticsService.instance.search(normalized);
    });
  }

  Future<void> _pickAddress() async {
    if (!context.read<AuthProvider>().isSignedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final address = await Navigator.of(context).push<DeliveryAddress>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (address != null && mounted) {
      // Anything picked on the map is a real address the customer wants
      // to use again, not a one-off — save it rather than only holding it
      // in memory for this session.
      await context.read<AddressProvider>().addNew(address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final catalog = context.watch<CatalogProvider>();
    final address = context.watch<AddressProvider>().address;
    final banners = context.watch<BannerProvider>().banners;
    final connectivity = context.watch<ConnectivityService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(
            addressLine: address?.shortLine(s.houseLabel),
            onTapAddress: _pickAddress,
            searchController: _search,
            searchHint: s.searchHint,
            deliveryAddressLabel: s.deliveryAddressLabel,
            onSearchChanged: _handleSearchChanged,
          ),
          Expanded(
            child: !connectivity.online && catalog.dishes.isEmpty
                ? _OfflineState(message: s.offlineNoConnection)
                : catalog.loading
                ? const HomeLoadingSkeleton()
                : RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: catalog.load,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ).copyWith(top: 8),
                      children: [
                        // Searching narrows the whole page to just its
                        // results — the banner and section browsing are for
                        // discovery, and a search already says what the
                        // customer wants.
                        if (catalog.query.isEmpty) ...[
                          if (banners.isNotEmpty)
                            BannerCarousel(banners: banners),
                          const SizedBox(height: 6),
                          Column(
                            children: [
                              _MenuHeading(
                                title: s.sections,
                                allLabel: s.all,
                                selectedCategory: _category,
                                onShowAll: () =>
                                    setState(() => _category = null),
                              ),
                              _CategoryChips(
                                categories: catalog.categories,
                                selected: _category,
                                popularLabel: s.categoryPopular,
                                onSelect: (id) {
                                  setState(() => _category = id);
                                  AnalyticsService.instance.categorySelected(
                                    id,
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              if (_category == null)
                                for (final category
                                    in catalog.homeCategories) ...[
                                  _HomeCategoryShelf(
                                    category: category,
                                    dishes: catalog.homeDishesForCategory(
                                      category.id,
                                    ),
                                    strings: s,
                                    onToggleFavorite: catalog.toggleFavorite,
                                  ),
                                  const SizedBox(height: 30),
                                ]
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),

                                  child: DishGrid(
                                    dishes: catalog.forCategory(_category),
                                    strings: s,
                                    onToggleFavorite: catalog.toggleFavorite,
                                  ),
                                ),
                            ],
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: DishGrid(
                              dishes: catalog.forCategory(_category),
                              strings: s,
                              onToggleFavorite: catalog.toggleFavorite,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MenuHeading extends StatelessWidget {
  const _MenuHeading({
    required this.title,
    required this.allLabel,
    required this.selectedCategory,
    required this.onShowAll,
  });

  final String title;
  final String allLabel;
  final String? selectedCategory;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Container(
    // TextButton's own minimum tap-target height is taller than the title
    // text — pinning the row to the title's height keeps it constant
    // whether or not the button is showing, instead of growing on select.
    height: 35,
    padding: const EdgeInsets.only(left: 16, right: 20, bottom: 4),
    child: Row(
      children: [
        Text(title, style: AppText.h2.copyWith(fontSize: 20)),
        const Spacer(),
        if (selectedCategory != null)
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(allLabel),
          ),
      ],
    ),
  );
}

class _HomeCategoryShelf extends StatelessWidget {
  const _HomeCategoryShelf({
    required this.category,
    required this.dishes,
    required this.strings,
    required this.onToggleFavorite,
  });

  final DishCategory category;
  final List<Dish> dishes;
  final AppStrings strings;
  final void Function(Dish) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDishesScreen(
                  categoryId: category.id,
                  categoryName: category.name,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: DishThumbnail(
                      dish: dishes.first,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: AppText.h2.copyWith(fontSize: 19),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          strings.dishesCount(dishes.length),
                          style: AppText.bodyMuted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    strings.all,
                    style: AppText.chip.copyWith(color: AppColors.orange),
                  ),
                  const SizedBox(width: 4),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: AppColors.orange,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          DishGrid(
            dishes: dishes,
            strings: strings,
            onToggleFavorite: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/no_connection.png',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: AppText.h2),
        ],
      ),
    ),
  );
}

class _Header extends StatefulWidget {
  const _Header({
    required this.addressLine,
    required this.onTapAddress,
    required this.searchController,
    required this.searchHint,
    required this.deliveryAddressLabel,
    required this.onSearchChanged,
  });

  final String? addressLine;
  final VoidCallback onTapAddress;
  final TextEditingController searchController;
  final String searchHint;
  final String deliveryAddressLabel;
  final void Function(String) onSearchChanged;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  // Matches the search TextField's natural height (contentPadding 16 top/bottom
  // + text line) so pinning both crossfade faces to it doesn't clip either one.
  static const _fieldHeight = 54.0;

  bool _searchOpen = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    } else {
      _searchFocus.unfocus();
      widget.searchController.clear();
      widget.onSearchChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.green,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        20,
        20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // Fixed height on both faces so the crossfade itself never
            // resizes — otherwise AnimatedCrossFade tweens between the
            // address block's height and the field's, and the whole header
            // grows/shrinks with it.
            child: SizedBox(
              height: _fieldHeight,
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 260),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
                sizeCurve: Curves.easeOut,
                crossFadeState: _searchOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: SizedBox(
                  height: _fieldHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.onTapAddress,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.deliveryAddressLabel,
                            style: AppText.label.copyWith(
                              color: AppColors.greenMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.addressLine ?? '—',
                            style: AppText.h1.copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                secondChild: SizedBox(
                  height: _fieldHeight,
                  child: TextField(
                    focusNode: _searchFocus,
                    controller: widget.searchController,
                    onChanged: widget.onSearchChanged,
                    style: AppText.body,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: HugeIcon(
                          icon: AppIcons.search,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.greenSurface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleSearch,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: _searchOpen ? AppIcons.cancel : AppIcons.search,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.popularLabel,
    required this.onSelect,
  });

  final List<DishCategory> categories;
  final String? selected;
  final String popularLabel;
  final void Function(String? id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,

      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        scrollDirection: Axis.horizontal,
        children: [
          for (final category in categories) ...[
            const SizedBox(width: 8),
            _Chip(
              label: category.name,
              active: selected == category.id,
              onTap: () => onSelect(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active ? AppColors.green : AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Text(
                label,
                style: AppText.chip.copyWith(
                  color: active ? AppColors.white : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
