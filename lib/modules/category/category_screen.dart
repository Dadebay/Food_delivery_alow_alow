import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/models/dish.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/delivery_loader.dart';
import '../catalog/catalog_provider.dart';
import 'category_dishes_screen.dart';

/// Category tab — every section as its own card, tapping opens the filtered
/// dish list. Replaces Favourites in the bottom nav (favourites now lives in
/// the profile screen, since it's a personal list rather than a way to browse
/// the menu).
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _scrollController = ScrollController();

  /// When the grid first became visible. `GridView.builder` builds a tile the
  /// moment it scrolls into range, so an index-based entrance delay makes a
  /// tile built on scroll wait its whole stagger before appearing — with 40
  /// categories the last one sat blank for over a second. The entrance is a
  /// first-paint flourish, so it only applies to tiles built right after the
  /// grid appeared; anything built later is a scroll, and must be instant.
  DateTime? _shownAt;

  /// Past this point a tile is being built because the courier scrolled to
  /// it, not because the screen just opened.
  static const _entranceWindow = Duration(milliseconds: 500);

  /// Cards past the first screenful all start together — the stagger exists
  /// to make the opening screen read as composed, not to delay row 12.
  static const _staggerLimit = 6;

  /// List view gives each card far more height, so the same pixel drift
  /// reads as a much more obvious parallax move than it does squeezed into
  /// a 2-column tile.
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.dishes.isEmpty) catalog.load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Saturated brand tones — not the pale *Soft variants — so the white
  // overlay text stays legible even on a category with no dish photo yet.
  static const _palette = [
    AppColors.green,
    AppColors.orange,
    AppColors.greenLight,
    AppColors.gold,
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final catalog = context.watch<CatalogProvider>();
    if (!catalog.loading) _shownAt ??= DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(s.sections),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              tooltip: _isGridView ? s.listView : s.gridView,
              onPressed: () => setState(() => _isGridView = !_isGridView),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.greenMuted),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
              ),
              icon: HugeIcon(
                icon: _isGridView ? AppIcons.listView : AppIcons.category,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: catalog.loading
          // Stamped once, when the grid actually appears — the entrance
          // window is measured from there, not from the first tile built.
          ? ColoredBox(
              color: AppColors.loaderBackground,
              child: Center(
                child: DeliveryLoader(size: 200, message: s.loadingHint),
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: catalog.categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _isGridView ? 2 : 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: _isGridView ? 1.02 : 2.1,
              ),
              itemBuilder: (context, index) {
                final category = catalog.categories[index];
                final dishes = catalog.forCategory(category.id);
                final shownAt = _shownAt;
                final isFirstPaint =
                    shownAt != null &&
                    DateTime.now().difference(shownAt) < _entranceWindow;
                final card = _ParallaxCategoryCard(
                  scrollController: _scrollController,
                  // The admin-selected cover always takes precedence.
                  // Keep a product photo as a helpful fallback for
                  // older categories.
                  imageUrl:
                      category.imageUrl ??
                      (dishes.isEmpty ? null : dishes.first.imageUrl),
                  name: category.name,
                  countLabel: s.dishesCount(dishes.length),
                  tint: _palette[index % _palette.length],
                  onTap: () => _openCategory(context, category),
                );
                if (!isFirstPaint) return card;
                // Staggered pop-in — the grid reads as composed rather
                // than just appearing all at once.
                final step = index < _staggerLimit ? index : _staggerLimit;
                return card
                    .animate(delay: (35 * step).ms)
                    .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.14,
                      end: 0,
                      duration: 360.ms,
                      curve: Curves.easeOutCubic,
                    );
              },
            ),
    );
  }

  void _openCategory(BuildContext context, DishCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryDishesScreen(
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }
}

/// Tracks how far this box has scrolled from screen-centre and publishes the
/// pixel offset as a [ValueListenable] — the shared plumbing behind every
/// parallax tile on this screen, grid tile or list row alike.
///
/// The offset is deliberately *not* held in [State]: a `setState` per scroll
/// tick rebuilt every visible card's whole subtree — photo, gradient, labels
/// — several times a frame, which is what made a fast flick through 40
/// categories stutter. Handing out a listenable lets each card rebuild just
/// its [Transform] layer and leave the expensive children untouched.
class _ScrollDrift extends StatefulWidget {
  const _ScrollDrift({
    required this.controller,
    required this.range,
    required this.builder,
  });

  final ScrollController controller;
  final double range;
  final Widget Function(BuildContext context, ValueListenable<double> shift)
  builder;

  @override
  State<_ScrollDrift> createState() => _ScrollDriftState();
}

class _ScrollDriftState extends State<_ScrollDrift> {
  final _key = GlobalKey();
  final _shift = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _shift.dispose();
    super.dispose();
  }

  void _update() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !mounted) return;
    final viewport = MediaQuery.sizeOf(context).height;
    final centerY = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
    final fraction = ((centerY - viewport / 2) / viewport).clamp(-0.6, 0.6);
    final next = fraction * widget.range;
    // Sub-pixel drift is invisible; skipping it keeps a slow scroll from
    // repainting on every single tick.
    if ((next - _shift.value).abs() > 0.4) _shift.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.builder(context, _shift));
  }
}

/// A category tile that reads as a real menu photo rather than a flat
/// colour swatch: the dish photo behind it drifts a few pixels against the
/// scroll — the same lightweight parallax trick as a hero banner — so the
/// grid feels alive instead of static as it's scrolled past.
class _ParallaxCategoryCard extends StatelessWidget {
  const _ParallaxCategoryCard({
    required this.scrollController,
    required this.imageUrl,
    required this.name,
    required this.countLabel,
    required this.tint,
    required this.onTap,
  });

  final ScrollController scrollController;
  final String? imageUrl;
  final String name;
  final String countLabel;
  final Color tint;
  final VoidCallback onTap;

  static const _radius = 30.0;
  static const _bleed = 56.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          // Soft, colour-matched glow — reads as depth rather than a
          // generic grey drop shadow.
          BoxShadow(
            color: tint.withValues(alpha: 0.38),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          // Tight contact shadow that grounds the card against the page.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: _ScrollDrift(
            controller: scrollController,
            range: 46,
            builder: (context, shift) => Stack(
              fit: StackFit.expand,
              children: [
                // Always drifts — whether it ends up showing the real dish
                // photo or (missing/broken asset) the watermark fallback,
                // both live inside this same translated layer.
                Positioned(
                  top: -_bleed,
                  bottom: -_bleed,
                  left: 0,
                  right: 0,
                  // The photo is passed as `child`, so it is built once and
                  // only the translation is recomputed as the card drifts.
                  child: ValueListenableBuilder<double>(
                    valueListenable: shift,
                    child: _CategoryImage(url: imageUrl, tint: tint),
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, value),
                      child: child,
                    ),
                  ),
                ),
                // Bottom-up scrim, tall and dark enough that the name reads
                // cleanly over a busy photo or the watermark alike.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xB3000000),
                      ],
                      stops: [0.0, 0.25, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        name,
                        style: AppText.h2.copyWith(
                          fontSize: 20,
                          color: AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countLabel,
                        style: AppText.bodyMuted.copyWith(
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders [url] — asset path or network URL — and falls back to a
/// [tint]-coloured watermark glyph whenever it's missing or fails to load,
/// same policy as [DishThumbnail] but for a category tile rather than a
/// dish.
class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.url, required this.tint});

  final String? url;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final value = url;
    final fallback = _CategoryWatermark(tint: tint);
    if (value == null || value.isEmpty) return fallback;
    if (value.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: value,
        fit: BoxFit.cover,
        // A menu photo is uploaded at full camera resolution; decoding that
        // at its native size for every tile is what made images land a beat
        // after the card during a fast flick. Screen width is the widest a
        // tile ever gets (list view) and is a safe cap for both layouts.
        memCacheWidth:
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (context, url, error) => fallback,
      );
    }
    return Image.asset(
      value,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _CategoryWatermark extends StatelessWidget {
  const _CategoryWatermark({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tint,
      child: Center(
        child: HugeIcon(
          icon: AppIcons.foodWatermark,
          color: AppColors.white.withValues(alpha: 0.32),
          size: 88,
        ),
      ),
    );
  }
}
