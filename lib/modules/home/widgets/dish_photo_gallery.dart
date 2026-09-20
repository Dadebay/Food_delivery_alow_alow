import 'package:flutter/material.dart';

import '../../../core/models/dish.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../photo_viewer_screen.dart';

/// The dish page's photo area: every photo the backend holds for the dish,
/// swipeable, with a page indicator and a tap through to the full-screen
/// zoomable viewer.
///
/// A single photo deliberately skips the pager entirely — a PageView around
/// one page still installs scroll physics that fight the page's own vertical
/// scroll on a diagonal drag, for no gain.
class DishPhotoGallery extends StatelessWidget {
  const DishPhotoGallery({
    super.key,
    required this.dish,
    required this.photos,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    this.dotsBottomInset = 0,
  });

  final Dish dish;
  final List<String> photos;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  /// How far above the bottom edge the dots sit — the dish page's white
  /// sheet rides up over the photo and would otherwise cover them.
  final double dotsBottomInset;

  void _openViewer(BuildContext context) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => _openViewer(context),
          child: photos.length < 2
              ? DishThumbnail(
                  dish: dish,
                  borderRadius: BorderRadius.zero,
                  imageUrlOverride: photos.isEmpty ? null : photos.first,
                )
              // No itemCount: the pager runs on forever and the photo is
              // picked modulo the gallery, so the last photo leads back to
              // the first rather than stopping against an edge.
              : PageView.builder(
                  controller: controller,
                  onPageChanged: (i) => onPageChanged(i % photos.length),
                  itemBuilder: (context, i) => DishThumbnail(
                    dish: dish,
                    borderRadius: BorderRadius.zero,
                    imageUrlOverride: photos[i % photos.length],
                  ),
                ),
        ),
        // Both overlays are decoration and must stay out of the pager's way:
        // a DecoratedBox laid over the photo swallows the pointer, and that
        // alone is what kept the gallery from swiping at all.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x40000000), Colors.transparent],
                stops: [0.0, 0.32],
              ),
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: dotsBottomInset,
            child: IgnorePointer(
              child: _PhotoDots(count: photos.length, active: index),
            ),
          ),
      ],
    );
  }
}

/// The page indicator under the gallery.
class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          // The current page stretches rather than just brightening, so the
          // position reads at a glance over a busy photo.
          width: i == active ? 18 : 6,
          decoration: BoxDecoration(
            color: i == active
                ? AppColors.white
                : AppColors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}
