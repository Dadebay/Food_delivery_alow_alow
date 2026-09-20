import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/dish.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/cart_fly_animation.dart';
import '../../core/widgets/dish_grid.dart';
import '../../core/widgets/favorite_toggle.dart';
import '../catalog/catalog_provider.dart';
import '../cart/cart_provider.dart';
import 'widgets/dish_photo_gallery.dart';

/// A dish's own page — full-bleed photo, a white sheet of details riding
/// up over it, then a shelf of other dishes from the same category so
/// browsing doesn't dead-end here.
///
/// Replaces the old bottom sheet: a sheet is for a quick glance, but with a
/// related-dishes shelf underneath there's a whole page of content to
/// scroll through, and that wants a real screen with its own back button
/// and scroll position — not a sheet fighting the keyboard for height.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dish});

  final Dish dish;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  /// Height of the dish photo.
  ///
  /// A fixed 320 is right on a phone, where it is about three quarters of the
  /// width. On a tablet the same number is a short band across a very wide
  /// screen, and `BoxFit.cover` answers that shape by cropping almost
  /// everything above and below the middle of the plate. Tying the height to
  /// the width keeps the crop the same on every screen.
  static double _photoHeightFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    // Never more than half the screen: the name, price and the add button
    // still have to be visible without scrolling.
    return (width * 0.72).clamp(320.0, height * 0.5);
  }

  static const _sheetOverlap = 26.0;

  // Fixed at 1 — no on-page stepper; adjusting the quantity happens on the
  // grid's own quick-add stepper after the dish is in the cart.
  static const _quantity = 1;
  final TextEditingController _note = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// The photo gallery lives on its own controller so switching variant can
  /// snap it back to the first page — the new variant's photos are a
  /// different set, and staying on page 3 of the old one is meaningless.
  /// Starts deep into the pager so the gallery wraps in both directions —
  /// see [DishPhotoGallery]. The base is a multiple of the gallery, so the
  /// starting page is the first photo.
  static const _galleryLoops = 1000;
  late final PageController _photoController = PageController(initialPage: widget.dish.gallery.length * _galleryLoops);
  int _photoIndex = 0;

  /// The size/weight currently picked for a VARIANT dish. It deliberately
  /// starts empty: the API contract forbids silently choosing the cheapest
  /// option for the customer.
  DishVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.dishOpened(widget.dish);
  }

  @override
  void dispose() {
    _note.dispose();
    _scrollController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  /// Picking a variant swaps the gallery underneath, so the pager goes back
  /// to the first photo rather than holding an index into a set that is no
  /// longer on screen.
  void _selectVariant(DishVariant variant) {
    setState(() {
      _selectedVariant = variant;
      _photoIndex = 0;
    });
    if (_photoController.hasClients) {
      // A variant with no photos of its own keeps showing the dish's, so the
      // base has to come from whichever gallery is actually on screen.
      final photos = variant.gallery.isNotEmpty ? variant.gallery : widget.dish.gallery;
      _photoController.jumpToPage(photos.length * _galleryLoops);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dish = widget.dish;
    final catalog = context.watch<CatalogProvider>();
    final photoHeight = _photoHeightFor(context);
    // A variant with photos of its own replaces the dish's gallery; one
    // without simply keeps showing the dish's.
    final variantGallery = _selectedVariant?.gallery ?? const <String>[];
    final photos = variantGallery.isNotEmpty ? variantGallery : dish.gallery;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: photoHeight,
                backgroundColor: AppColors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _RoundIconButton(icon: AppIcons.back, onTap: () => Navigator.of(context).pop()),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    // Same 36px disc as the back button opposite it. The
                    // glyph is the larger number because it carries its own
                    // white halo inside the drawing.
                    child: FavoriteToggle(active: dish.isFavorite, onTap: () => catalog.toggleFavorite(dish), size: 30, background: AppColors.white.withValues(alpha: 0.92)),
                  ),
                ],
                // Sits invisible in the collapsed toolbar row while the
                // photo is still open, and only fades in once the photo has
                // fully scrolled away — driven off actual scroll offset
                // rather than FlexibleSpaceBar's own built-in fade, which
                // shows the title too early, still over the photo.
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final collapseDistance = photoHeight - kToolbarHeight;
                    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                    final progress = collapseDistance <= 0 ? 1.0 : (offset / collapseDistance).clamp(0.0, 1.0);
                    return Opacity(opacity: progress, child: child);
                  },
                  child: Text(dish.name, style: AppText.h2.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      DishPhotoGallery(
                        dish: dish,
                        photos: photos,
                        controller: _photoController,
                        index: _photoIndex,
                        onPageChanged: (index) => setState(() => _photoIndex = index),
                        dotsBottomInset: _sheetOverlap + 14,
                      ),
                      if (dish.hasDiscount)
                        Positioned(
                          left: 16,
                          bottom: _sheetOverlap + 14,
                          child: IgnorePointer(child: _Badge(text: '-${dish.discountPercent}%')),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -_sheetOverlap),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    // Extra top padding, beyond just the sheet's own
                    // overlap into the photo — otherwise the name sits
                    // right at the rounded edge, crowding the photo.
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dish.name, style: AppText.h2.copyWith(fontSize: 25)),
                        if (_meta(dish, s).isNotEmpty) ...[const SizedBox(height: 6), Text(_meta(dish, s), style: AppText.bodyMuted)],
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _selectedVariant == null && dish.hasVariants ? s.fromPrice(Fmt.money(dish.minimumPrice)) : Fmt.money(_selectedVariant?.price ?? dish.discountedPrice),
                              style: AppText.figure.copyWith(fontSize: 22),
                            ),
                            if (_selectedVariant == null && dish.hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(Fmt.money(dish.price), style: AppText.bodyMuted.copyWith(decoration: TextDecoration.lineThrough)),
                            ],
                          ],
                        ),
                        if (dish.hasVariants && dish.variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _VariantPicker(label: dish.variantLabel, variants: dish.variants, selected: _selectedVariant, onSelected: _selectVariant),
                        ],
                        if (dish.description.isNotEmpty) ...[const SizedBox(height: 14), Text(dish.description, style: AppText.bodyMuted)],
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(
                child: _RelatedDishes(dish: dish, catalog: catalog, title: s.moreFromCategory),
              ),
              // Clears the floating "add to cart" bar, which has no
              // background of its own to reserve this space by itself.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AddToCartBar(dish: dish, variant: _selectedVariant, quantity: _quantity, note: _note),
          ),
        ],
      ),
    );
  }

  String _meta(Dish dish, AppStrings s) {
    final parts = <String>[];
    if (dish.portionLabel != null) parts.add(dish.portionLabel!);
    if (dish.prepMinutes != null) parts.add(s.minutesShort(dish.prepMinutes!));
    return parts.join(' · ');
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({required this.dish, required this.variant, required this.quantity, required this.note});

  final Dish dish;
  final DishVariant? variant;
  final int quantity;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final needsVariant = dish.hasVariants && variant == null;
    final unitPrice = variant?.price ?? dish.displayedBasePrice;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: AppButton(
          label: needsVariant ? s.selectVariantFirst : '${s.addToCart} · ${Fmt.money(unitPrice * quantity)}',
          onPressed: needsVariant
              ? null
              : () {
                  context.read<CartProvider>().add(dish, variant: variant, quantity: quantity, note: note.text.trim().isEmpty ? null : note.text.trim());
                  AnalyticsService.instance.addedToCart(dish, quantity);
                  // Started before popping — the overlay it flies in is
                  // attached to the root navigator, so the animation keeps
                  // playing over whatever screen this pop reveals.
                  CartFlyAnimation.runFrom(fromContext: context, imageUrl: variant?.imageUrl ?? dish.imageUrl);
                  Navigator.of(context).pop();
                },
        ),
      ),
    );
  }
}

/// Rounded, admin-labelled choice chips for picking one of the dish's
/// variants (size, weight, ...) — the only way to change what's about to be
/// added, since the fixed on-page quantity of 1 means this row is the whole
/// "configure before adding" step for a dish with variants.
class _VariantPicker extends StatelessWidget {
  const _VariantPicker({required this.label, required this.variants, required this.selected, required this.onSelected});

  final String? label;
  final List<DishVariant> variants;
  final DishVariant? selected;
  final ValueChanged<DishVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[Text(label!, style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 8)],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variants.map((variant) {
            final active = variant.id == selected?.id;
            return ChoiceChip(
              label: Text(variant.name),
              selected: active,
              onSelected: (_) => onSelected(variant),
              showCheckmark: false,
              labelStyle: AppText.chip.copyWith(fontWeight: FontWeight.w700, color: active ? AppColors.white : AppColors.textPrimary),
              backgroundColor: AppColors.cream,
              selectedColor: AppColors.orange,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RelatedDishes extends StatelessWidget {
  const _RelatedDishes({required this.dish, required this.catalog, required this.title});

  final Dish dish;
  final CatalogProvider catalog;
  final String title;

  @override
  Widget build(BuildContext context) {
    final related = catalog.forCategory(dish.categoryId).where((d) => d.id != dish.id).toList();
    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: Text(title, style: AppText.h2.copyWith(fontSize: 22)),
        ),
        // The grid keeps no horizontal inset of its own — every other caller
        // wraps it in the page's gutter, and this one has to as well or the
        // cards run to the screen edge while the heading above them sits
        // inset.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DishGrid(dishes: related, strings: context.s, onToggleFavorite: catalog.toggleFavorite),
        ),
        SizedBox(height: 40),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final HugeIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: HugeIcon(icon: icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: AppText.chip.copyWith(color: AppColors.white, fontSize: 12)),
    );
  }
}

/// The dish photo, swipeable when the backend holds more than one.
///
/// A single photo deliberately skips the pager entirely: a PageView around
/// one page still installs scroll physics that fight the page's own vertical
/// scroll on a diagonal drag, for no gain.
