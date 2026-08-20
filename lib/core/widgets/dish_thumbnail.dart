import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/dish.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// A dish's image tile.
///
/// Renders [Dish.imageUrl] — an asset path or a network URL — and falls back
/// to a warm branded tile whenever it's missing or fails to load. The card
/// around it is photo-first, so the fallback has to carry the card on its
/// own: a flat grey rectangle under a dark scrim reads as broken, a tinted
/// tile with a food glyph reads as "photo coming".
class DishThumbnail extends StatelessWidget {
  const DishThumbnail({super.key, required this.dish, this.borderRadius});

  final Dish dish;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final url = dish.imageUrl;
    final fallback = _Fallback(seed: dish.id);

    Widget image;
    if (url == null || url.isEmpty) {
      image = fallback;
    } else if (url.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback,
      );
    } else {
      image = Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return ClipRRect(borderRadius: radius, child: image);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.seed});

  /// The dish id — picks the tone, so a grid of photo-less dishes varies
  /// tile to tile instead of being one flat block of colour, and each dish
  /// keeps the same tone every time it's drawn.
  final String seed;

  static const _tones = [
    (Color(0xFF14513E), Color(0xFF0B3B2E)),
    (Color(0xFFD9640F), Color(0xFFA8480A)),
    (Color(0xFFB98A2A), Color(0xFF8A6418)),
    (Color(0xFF1D6B50), Color(0xFF11493A)),
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
