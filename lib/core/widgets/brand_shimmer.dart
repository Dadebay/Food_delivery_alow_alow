import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'shimmer.dart';

/// What a photo's place looks like before the photo arrives: a flat grey
/// field with the brand wordmark sweeping across it.
///
/// It replaces the tinted "photo coming" tile on the loading path only. A
/// dish that has no photo at all still gets that tile — a wordmark that
/// never resolves into a picture reads as a stuck app.
class BrandShimmerBox extends StatelessWidget {
  const BrandShimmerBox({super.key, this.radius = 0, this.wordmarkSize = 18});

  final double radius;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.divider,
      borderRadius: BorderRadius.circular(radius),
    ),
    // The same placeholder stands in for a full-bleed dish photo and for a
    // 48px shelf thumbnail, so the wordmark shrinks to whatever it is given
    // rather than overflowing the small ones. It never grows past
    // [wordmarkSize] — scaled up it would read as a logo, not a placeholder.
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: BrandShimmerText(size: wordmarkSize),
        ),
      ),
    ),
  );
}

/// The sweeping wordmark on its own, for placeholders that bring their own
/// background.
class BrandShimmerText extends StatelessWidget {
  const BrandShimmerText({super.key, this.size = 18});

  final double size;

  /// The wordmark as it is written, not the package name.
  static const wordmark = 'AlowAlow';

  @override
  Widget build(BuildContext context) => Shimmer(
    // The box behind this paints `divider`, so the wordmark's resting colour
    // has to be darker than that or only the sweep would be visible.
    baseColor: AppColors.textMuted,
    child: Text(
      wordmark,
      style: TextStyle(
        fontFamily: AppText.wordmarkFamily,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        // The shimmer's shader paints over this; the colour only has to be
        // opaque enough for the sweep to have something to mask.
        color: AppColors.textMuted,
      ),
    ),
  );
}
