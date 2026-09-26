import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/dish.dart';
import '../services/catalog_image_cache_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'brand_shimmer.dart';

/// A dish's image tile.
///
/// Renders [Dish.imageUrl] — an asset path or a network URL — and falls back
/// to a warm branded tile whenever it's missing or fails to load. The card
/// around it is photo-first, so the fallback has to carry the card on its
/// own: a flat grey rectangle under a dark scrim reads as broken, a tinted
/// tile with a food glyph reads as "photo coming".
class DishThumbnail extends StatelessWidget {
  const DishThumbnail({
    super.key,
    required this.dish,
    this.borderRadius,
    this.imageUrlOverride,
  });

  final Dish dish;
  final BorderRadius? borderRadius;


  /// Shown instead of [dish.imageUrl] when set — e.g. the photo of whichever
  /// variant is currently selected on the dish's own page. Falls back to
  /// the dish's own photo when the variant has none of its own.
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final branded = _Fallback(seed: dish.id);

    final variantUrl = _usable(imageUrlOverride);
    final dishUrl = _usable(dish.imageUrl);

    // Variant photo, then the dish's own, then the branded tile — each step
    // catching the one before it.
    //
    // The middle step used to be missing, and it is the whole reason a cart
    // row could look photo-less while the same dish showed fine on the menu:
    // the cart is the only screen that passes an override, and an override
    // that was empty or failed to load dropped straight to the gradient
    // instead of the photo the dish had all along.
    // A dish with no photo at all keeps the tinted tile — there is nothing
    // coming, and a wordmark that never resolves would read as a stuck app.
    // A dish that *has* a photo the phone could not fetch is a different
    // story: that is the network, not the menu, so it gets the same grey
    // field and sweeping wordmark every loading photo in the app shows.
    var image = dishUrl == null
        ? branded
        : _image(context, dishUrl, const BrandShimmerBox());
    if (variantUrl != null && variantUrl != dishUrl) {
      image = _image(context, variantUrl, image);
    }

    return ClipRRect(borderRadius: radius, child: image);
  }

  /// An empty string is "no photo", same as null — the backend sends one for
  /// a variant that has no image of its own, and `??` alone would take it.
  static String? _usable(String? url) =>
      url == null || url.isEmpty ? null : url;

  Widget _image(BuildContext context, String url, Widget onError) {
    if (!url.startsWith('http')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => onError,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: CatalogImageCacheManager.instance,
      fit: BoxFit.cover,
      // Menu photos are uploaded at camera resolution. Decoding one at its
      // native size costs both time and a large chunk of the image cache,
      // and a dish tile is never wider than half the screen — so cap the
      // decode there and keep a scrolling grid cheap.
      memCacheWidth:
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context) /
                  2)
              .round(),
      fadeInDuration: const Duration(milliseconds: 150),
      // Without this the tile is blank while the photo is in flight, and a
      // photo that never arrives — a stalled TLS handshake rather than a
      // clean error — leaves a pure white card forever, with nothing to say
      // whether the dish has an image at all. The branded tile shows up
      // immediately and the photo fades in over it.
      // A photo in flight gets the grey field and the sweeping wordmark,
      // which says "loading" plainly; the tinted tile below is kept for a
      // dish that has no photo at all, where a wordmark that never resolves
      // into a picture would read as a stuck app.
      placeholder: (context, url) => const BrandShimmerBox(),
      errorWidget: (context, url, error) => onError,
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.seed});

  /// The dish id — picks the tone, so a grid of photo-less dishes varies
  /// tile to tile instead of being one flat block of colour, and each dish
  /// keeps the same tone every time it's drawn.
  final String seed;

  /// Warm tones only — these were greens, which now read as a leftover from
  /// the previous palette wherever a dish has no photo yet.
  static const _tones = [
    (Color(0xFFE23744), Color(0xFFA30D24)),
    (Color(0xFFD9640F), Color(0xFFA8480A)),
    (Color(0xFFB98A2A), Color(0xFF8A6418)),
    (Color(0xFFE08A1E), Color(0xFFB2600C)),
  ];

  @override
  Widget build(BuildContext context) {
    final (from, to) = _tones[seed.hashCode.abs() % _tones.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.4,
          child: FittedBox(
            child: HugeIcon(
              icon: AppIcons.foodWatermark,
              color: AppColors.white.withValues(alpha: 0.26),
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
