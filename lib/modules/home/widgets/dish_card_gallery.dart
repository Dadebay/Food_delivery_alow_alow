import 'package:flutter/material.dart';

import '../../../core/models/dish.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dish_thumbnail.dart';

/// The photo on a dish card: swipeable when the dish has more than one, so
/// the second and third photo are reachable without opening the dish.
///
/// A dish with a single photo gets a plain thumbnail and no pager. That is
/// not only about cost — a PageView installs horizontal scroll physics that
/// make a diagonal drag ambiguous against the grid's own vertical scroll,
/// and a card with nothing to page through should never take that from the
/// grid.
class DishCardGallery extends StatefulWidget {
  const DishCardGallery({super.key, required this.dish});

  final Dish dish;

  @override
  State<DishCardGallery> createState() => _DishCardGalleryState();
}

class _DishCardGalleryState extends State<DishCardGallery> {
  PageController? _controller;
  int _page = 0;

  /// How many galleries' worth of pages sit on either side of the start.
  /// Large enough that nobody swipes out of it, small enough to stay well
  /// inside a sane page count.
  static const _loops = 1000;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.dish.gallery;

    if (photos.length < 2) {
      return DishThumbnail(dish: widget.dish, borderRadius: BorderRadius.zero);
    }

    // Starting deep into the pager rather than at 0 leaves room to swipe
    // backwards off the first photo too: a PageView with no itemCount runs
    // forever forwards, but still stops at page 0 going the other way. The
    // base is a multiple of the gallery, so page 0 of the loop is photo 0.
    final controller = _controller ??= PageController(
      initialPage: photos.length * _loops,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // No itemCount: the pager runs in both directions forever and the
        // photo is picked modulo the gallery, so the last one leads back to
        // the first instead of stopping dead against an edge. Dart's `%`
        // stays non-negative, so swiping the other way wraps just as well.
        PageView.builder(
          controller: controller,
          onPageChanged: (i) => setState(() => _page = i % photos.length),
          itemBuilder: (context, index) => DishThumbnail(
            dish: widget.dish,
            borderRadius: BorderRadius.zero,
            imageUrlOverride: photos[index % photos.length],
          ),
        ),
        // Decoration only — anything laid over the pager that takes the
        // pointer stops the card swiping at all.
        Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            child: _Dots(count: photos.length, index: _page),
          ),
        ),
      ],
    );
  }
}

/// The page indicator, on its own white pill so it reads over any photo.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  /// Beyond this the dots stop being readable at card size.
  static const _maxDots = 5;

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(0, _maxDots);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < shown; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == index ? 10 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == index ? AppColors.textPrimary : AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
