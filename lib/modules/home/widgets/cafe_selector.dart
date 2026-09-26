import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models/cafe.dart';
import '../../../core/services/catalog_image_cache_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brand_shimmer.dart';

/// The horizontal strip of cafes above the menu.
///
/// It stays on screen with the menu rather than living behind a full-screen
/// chooser, so switching cafe is one tap from whatever the customer is
/// looking at. Switching never touches the cart.
///
/// The palette is deliberately the app's own cream and orange: the earlier
/// draft of this read as a separate green marketplace widget bolted onto the
/// page. Cards stay pale so the cafe photos carry the difference between
/// them; the selected one warms slightly and gains a thin orange border
/// rather than a glow or a saturated fill.
class CafeSelector extends StatelessWidget {
  const CafeSelector({
    super.key,
    required this.cafes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Cafe> cafes;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  static const _cardWidth = 132.0;
  static const _imageHeight = 110.0;
  static const _gap = 12.0;
  static const _gutter = 12.0;

  /// Up to this many cafes are laid out across the full width instead of as a
  /// scrolling strip. Two or three cards fit comfortably; beyond that they
  /// would be too narrow to show a photo worth looking at.
  static const _fillWidthLimit = 3;

  @override
  Widget build(BuildContext context) {
    // One cafe is not a choice, and a strip with a single card that cannot be
    // switched away from is just clutter above the menu.
    if (cafes.length < 2) return const SizedBox.shrink();

    // Few enough to share the width: a scrolling strip that does not actually
    // scroll leaves an odd gap down the right-hand side, and the cards read
    // as an afterthought rather than the choice they are.
    if (cafes.length <= _fillWidthLimit) {
      final imageHeight = cafes.length == 2 ? 132.0 : 110.0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: SizedBox(
          height: imageHeight,
          child: Row(
            children: [
              for (var i = 0; i < cafes.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  child: _CafeCard(
                    cafe: cafes[i],
                    selected: cafes[i].id == selectedId,
                    imageHeight: imageHeight,
                    onTap: () => onSelect(cafes[i].id),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: _imageHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        itemCount: cafes.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final cafe = cafes[index];
          return SizedBox(
            width: _cardWidth,
            child: _CafeCard(
              cafe: cafe,
              selected: cafe.id == selectedId,
              imageHeight: _imageHeight,
              onTap: () => onSelect(cafe.id),
            ),
          );
        },
      ),
    );
  }
}

class _CafeCard extends StatelessWidget {
  const _CafeCard({
    required this.cafe,
    required this.selected,
    required this.imageHeight,
    required this.onTap,
  });

  final Cafe cafe;
  final bool selected;
  final double imageHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The chosen cafe's photo is shown as it is — full colour, no
            // filter. The others are drained towards grey, which is what
            // carries "not this one" now: dimming every card equally left
            // even the selected photo looking washed out, when that picture
            // is the whole point of the card.
            if (selected)
              _CafeImage(url: cafe.imageUrl)
            else
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_dimmedSaturation),
                child: _CafeImage(url: cafe.imageUrl),
              ),

            // The name sits on the photo rather than in a strip under it:
            // the strip cost a third of the card's height and left the
            // picture — the only thing that tells one cafe from another —
            // squeezed into what was left.
            //
            // The scrim under the name is kept as short and as light as the
            // text can stand on the selected card, and only deepens on the
            // ones stepping back: a gradient that starts at 45% of the
            // height was darkening more than half of the photo the customer
            // actually chose.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Colors.transparent, Color(0xCC000000)],
                    stops: selected ? const [0.62, 1.0] : const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Unselected cards step back a little so the chosen one reads at
            // a glance without needing a loud border. Lighter than it was —
            // the desaturation above now does most of this work, and the two
            // stacked turned the photo into a pale smear.
            if (!selected)
              IgnorePointer(
                child: ColoredBox(
                  color: AppColors.white.withValues(alpha: 0.16),
                ),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: IgnorePointer(
                child: Text(
                  cafe.name,
                  style: AppText.h2.copyWith(
                    fontSize: 15,
                    color: AppColors.white,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 6),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: AppIcons.check,
                      color: AppColors.onBrand,
                      size: 13,
                    ),
                  ),
                ),
              ),

            // The selected outline is the brand yellow, drawn inside the
            // card so it reads on a dark photo as well as a pale one.
            if (selected)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.brand, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Saturation at 45%, as the standard luminance-weighted matrix. Not zero:
  /// a fully grey card reads as disabled rather than as the option not
  /// currently chosen.
  static const List<double> _dimmedSaturation = <double>[
    0.5672, 0.3933, 0.0396, 0, 0, //
    0.1172, 0.8433, 0.0396, 0, 0, //
    0.1172, 0.3933, 0.4896, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// The cafe photo, or a quiet cream placeholder when it is missing.
///
/// Resolved the same way as product and category images — the url arrives as
/// a same-origin media path and is made absolute by the repository.
class _CafeImage extends StatelessWidget {
  const _CafeImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null || value.isEmpty) return const _CafeImageFallback();
    if (!value.startsWith('http')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CafeImageFallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: value,
      cacheManager: CatalogImageCacheManager.instance,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      // In flight, and failed-to-fetch, both read as "the photo is not here
      // yet" — the cream watermark tile stays for a cafe that has no photo
      // on record at all.
      placeholder: (_, _) => const BrandShimmerBox(),
      errorWidget: (_, _, _) => const BrandShimmerBox(),
    );
  }
}

class _CafeImageFallback extends StatelessWidget {
  const _CafeImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.cream,
    child: Center(
      child: HugeIcon(
        icon: AppIcons.foodWatermark,
        color: AppColors.orange.withValues(alpha: 0.35),
        size: 28,
      ),
    ),
  );
}
