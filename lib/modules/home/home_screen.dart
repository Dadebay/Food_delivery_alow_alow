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
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/dish_grid.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../category/category_dishes_screen.dart';
import '../catalog/catalog_provider.dart';
import '../checkout/address_picker_screen.dart';
import '../checkout/address_provider.dart';
import '../../core/widgets/delivery_loader.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/cafe_selector.dart';
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

  /// When the shelf list first had real content to show. `SliverList.builder`
  /// builds a shelf the moment it scrolls into range, so animating every
  /// shelf unconditionally meant a fast flick kept restarting a ~1.2s
  /// fade/slide/scale on each dish card as new shelves scrolled in — several
  /// times a second, that's what was making the feed stutter. The entrance
  /// is a first-paint flourish; anything built after this window is a
  /// scroll, not an arrival, and renders instantly.
  DateTime? _shownAt;
  static const _entranceWindow = Duration(milliseconds: 500);

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
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    // Harita kullanicinin mevcut adresi uzerinde acilsin: cogu zaman amac
    // bastan bir yer secmek degil, o adresi biraz duzeltmek. Adres yoksa
    // ekran kendi GPS'e gidiyor.
    final current = context.read<AddressProvider>().address;
    final address = await Navigator.of(context).push<DeliveryAddress>(
      MaterialPageRoute(builder: (_) => AddressPickerScreen(initial: current)),
    );
    if (address != null && mounted) {
      // Anything picked on the map is a real address the customer wants
      // to use again, not a one-off — save it rather than only holding it
      // in memory for this session.
      try {
        await context.read<AddressProvider>().addNew(address);
      } catch (_) {
        // The address is already active for this session; only the address
        // book missed out. Without this the rejection escaped as an
        // unhandled exception from a button handler, which in release just
        // looks like the app freezing on the map.
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: context.sr.addressNotSaved,
          kind: AppSnackKind.error,
          icon: AppIcons.location,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final catalog = context.watch<CatalogProvider>();
    final address = context.watch<AddressProvider>().address;
    final banners = context.watch<BannerProvider>().banners;
    final connectivity = context.watch<ConnectivityService>();
    if (!catalog.loading) _shownAt ??= DateTime.now();

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
                // Only a cold start gets the full-page skeleton; once the
                // categories are in, the page itself renders and just the
                // shelves keep shimmering.
                // A cafe switch empties the menu on purpose, but it must not
                // take the whole page with it: the customer needs to see
                // which cafe they landed on and be able to change their mind.
                : catalog.loading &&
                      catalog.categories.isEmpty &&
                      !catalog.switchingCafe
                ? const HomeLoadingSkeleton()
                : RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: catalog.load,
                    // Slivers rather than `ListView(children: [...])`: that
                    // form builds every child up front, and with a shelf per
                    // category each one carrying a shrink-wrapped grid, the
                    // first frame had to lay out the entire menu — hundreds
                    // of cards — before the page could show anything. As a
                    // sliver list the shelves are built as they scroll in.
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Searching narrows the whole page to just its
                        // results — the banner and section browsing are for
                        // discovery, and a search already says what the
                        // customer wants.
                        if (catalog.query.isEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                children: [
                                  if (banners.isNotEmpty)
                                    BannerCarousel(
                                      banners: banners,
                                      // A banner is a picture, so it should
                                      // grow with the glass rather than sit
                                      // as a phone-sized strip on a tablet.
                                      height: Responsive.isCompact(context)
                                          ? 240
                                          : 340,
                                    ),
                                  // The cafe strip sits between the banner
                                  // and the menu, so switching cafe never
                                  // costs the customer their place on the
                                  // page — and never their cart.
                                  if (catalog.cafes.length > 1) ...[
                                    const SizedBox(height: 14),
                                    CafeSelector(
                                      cafes: catalog.cafes,
                                      selectedId: catalog.selectedCafeId,
                                      onSelect: (id) {
                                        setState(() => _category = null);
                                        catalog.selectCafe(id);
                                      },
                                    ),
                                  ],
                                  // An empty heading over an empty chip row
                                  // is worse than nothing while the next
                                  // cafe's menu is still coming.
                                  if (!catalog.switchingCafe) ...[
                                    const SizedBox(height: 6),
                                    _MenuHeading(title: s.sections, allLabel: s.all, selectedCategory: _category, onShowAll: () => setState(() => _category = null)),
                                    _CategoryChips(
                                      categories: catalog.categories,
                                      selected: _category,
                                      popularLabel: s.categoryPopular,
                                      onSelect: (id) {
                                        setState(() => _category = id);
                                        AnalyticsService.instance.categorySelected(id);
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          ),
                          if (catalog.switchingCafe)
                            SliverToBoxAdapter(
                              child: _CafeSwitchingPanel(
                                message: s.cafeSwitching,
                                cafeName: catalog.cafes
                                    .where((c) => c.id == catalog.selectedCafeId)
                                    .map((c) => c.name)
                                    .firstOrNull,
                              ),
                            )
                          else if (catalog.loading)
                            const SliverToBoxAdapter(child: HomeLoadingSkeleton.shelves())
                          else if (_category == null)
                            SliverList.builder(
                              itemCount: catalog.homeCategories.length,
                              itemBuilder: (context, index) {
                                final category = catalog.homeCategories[index];
                                final shownAt = _shownAt;
                                final isFirstPaint = shownAt != null && DateTime.now().difference(shownAt) < _entranceWindow;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 30),
                                  child: _HomeCategoryShelf(
                                    category: category,
                                    dishes: catalog.homeDishesForCategory(category.id),
                                    strings: s,
                                    onToggleFavorite: catalog.toggleFavorite,
                                    animate: isFirstPaint,
                                  ),
                                );
                              },
                            )
                          else
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: DishGrid(dishes: catalog.forCategory(_category), strings: s, onToggleFavorite: catalog.toggleFavorite),
                              ),
                            ),
                        ] else
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: DishGrid(dishes: catalog.forCategory(_category), strings: s, onToggleFavorite: catalog.toggleFavorite),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
  const _MenuHeading({required this.title, required this.allLabel, required this.selectedCategory, required this.onShowAll});

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
            style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(allLabel),
          ),
      ],
    ),
  );
}

class _HomeCategoryShelf extends StatelessWidget {
  const _HomeCategoryShelf({required this.category, required this.dishes, required this.strings, required this.onToggleFavorite, required this.animate});

  final DishCategory category;
  final List<Dish> dishes;
  final AppStrings strings;
  final void Function(Dish) onToggleFavorite;

  /// See [DishGrid.animate] — off for every shelf built after the feed's
  /// first paint, which is what a scroll builds.
  final bool animate;

  /// Enough for the shelf to read as a section worth opening, without laying
  /// out a category's whole menu on the home tab.
  ///
  /// Tied to the column count so a shelf always ends on a full row: six cards
  /// across four columns left a row of two with two gaps beside it.
  static int _previewCount(BuildContext context) {
    final columns = Responsive.gridColumns(context);
    return columns <= 2 ? 6 : columns * 2;
  }

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
                builder: (_) => CategoryDishesScreen(categoryId: category.id, categoryName: category.name),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: DishThumbnail(dish: dishes.first, borderRadius: BorderRadius.circular(14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A step lighter than a screen heading: a shelf title
                        // repeats down the whole feed, and at full bold every
                        // one of them competes with the dish cards under it.
                        Text(category.name, style: AppText.h2.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(strings.dishesCount(dishes.length), style: AppText.bodyMuted.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(strings.all, style: AppText.chip.copyWith(color: AppColors.orange)),
                  const SizedBox(width: 4),
                  const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: AppColors.orange, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // A preview, not the category. Tapping the header row above opens
          // the full list, and the count next to the name already says how
          // much more there is.
          DishGrid(dishes: dishes, strings: strings, onToggleFavorite: onToggleFavorite, maxItems: _previewCount(context), animate: animate),
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
            child: Image.asset('assets/images/no_connection.png', width: 200, height: 200, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: AppText.h2),
        ],
      ),
    ),
  );
}

class _Header extends StatefulWidget {
  const _Header({required this.addressLine, required this.onTapAddress, required this.searchController, required this.searchHint, required this.deliveryAddressLabel, required this.onSearchChanged});

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
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
      color: AppColors.brand,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 20),
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
                crossFadeState: _searchOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
                          Text(widget.deliveryAddressLabel, style: AppText.label.copyWith(color: AppColors.brandMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(widget.addressLine ?? '—', style: AppText.h1.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        child: HugeIcon(icon: AppIcons.search, color: AppColors.textMuted, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.brandSurface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleSearch,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(icon: _searchOpen ? AppIcons.cancel : AppIcons.search, color: AppColors.onBrand, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.selected, required this.popularLabel, required this.onSelect});

  final List<DishCategory> categories;
  final String? selected;
  final String popularLabel;
  final void Function(String? id) onSelect;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    // The chips keep a phone's proportions on a phone; on a tablet both the
    // row and the label grow, or they read as a strip of fine print under a
    // very large banner.
    final chipHeight = compact ? 44.0 : 50.0;
    const gap = 8.0;

    // One row on a phone, two on a tablet.
    //
    // The second row exists to use width a tablet has and a phone does not.
    // On a phone it only costs height: the labels here are long Turkmen
    // category names, so a pair of stacked chips pushes the dish grid an
    // extra 50-odd pixels down the screen while showing the same handful of
    // categories the customer would reach by flicking sideways anyway.
    final rows = compact ? 1 : 2;

    // Filled top-then-bottom in columns rather than wrapped, so the whole
    // thing stays one horizontal scroll — the chips read as a single list,
    // just a denser one where there is room for it.
    final columns = <List<DishCategory>>[];
    for (var i = 0; i < categories.length; i += rows) {
      final end = i + rows;
      columns.add(
        categories.sublist(i, end > categories.length ? categories.length : end),
      );
    }

    return SizedBox(
      height: chipHeight * rows + gap * (rows - 1) + 16,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        scrollDirection: Axis.horizontal,
        itemCount: columns.length,
        itemBuilder: (context, index) {
          final pair = columns[index];
          return Padding(
            padding: const EdgeInsets.only(left: gap),
            // A horizontal list hands its items unbounded width, and
            // `stretch` against an unbounded constraint has nothing to
            // stretch to — it left the render tree recomputing parent data
            // during the semantics pass, which is the
            // `!semantics.parentDataDirty` assertion. IntrinsicWidth gives
            // the column the width of its wider chip first, so `stretch`
            // then means something.
            child: IntrinsicWidth(
              child: Column(
                // Both chips in a column share the wider one's width, so the
                // two rows line up instead of stepping in and out.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var row = 0; row < rows; row++) ...[
                    if (row > 0) const SizedBox(height: gap),
                    SizedBox(
                      height: chipHeight,
                      // The last column can be short of a full set; an empty
                      // box holds the gap so the row above keeps its height.
                      child: row < pair.length
                          ? _Chip(
                              label: pair[row].name,
                              active: selected == pair[row].id,
                              onTap: () => onSelect(pair[row].id),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
        color: active ? AppColors.brand : AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active ? [BoxShadow(color: AppColors.brand.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))] : null,
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
                  fontSize: Responsive.isCompact(context) ? null : 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the customer sees between one cafe's menu and the next.
///
/// Switching cafe is a real wait — a fresh category and product request —
/// and a page that simply empties looks like the tap broke something. The
/// courier animation is the app's own "working on it" signal, and naming the
/// cafe underneath confirms the choice landed.
class _CafeSwitchingPanel extends StatelessWidget {
  const _CafeSwitchingPanel({required this.message, this.cafeName});

  final String message;
  final String? cafeName;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
    child: Column(
      children: [
        const DeliveryLoader(size: 170),
        const SizedBox(height: 12),
        if (cafeName != null) ...[
          Text(
            cafeName!,
            style: AppText.h2.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
        ],
        Text(message, style: AppText.bodyMuted, textAlign: TextAlign.center),
      ],
    ),
  );
}
