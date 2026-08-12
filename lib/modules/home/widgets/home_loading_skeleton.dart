import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer.dart';

/// Stand-in for the whole home feed while the catalogue is still loading —
/// shaped like the real page (banner, heading, chips, category shelves of
/// dish cards) rather than one generic spinner, so the layout doesn't jump
/// once the real content lands.
///
/// The banner slot here is just a bone the same size as [BannerCarousel] —
/// it doesn't touch that widget or its file at all.
class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const ShimmerBone(height: 190, radius: 18),
          const SizedBox(height: 10),
          const Center(child: ShimmerBone(width: 70, height: 6, radius: 3)),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: ShimmerBone(width: 120, height: 22),
          ),
          const SizedBox(height: 14),
          const _ChipsRowSkeleton(),
          const SizedBox(height: 24),
          const _ShelfSkeleton(),
          const SizedBox(height: 30),
          const _ShelfSkeleton(),
        ],
      ),
    );
  }
}

class _ChipsRowSkeleton extends StatelessWidget {
  const _ChipsRowSkeleton();

  static const _widths = [76.0, 64.0, 88.0, 70.0, 60.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      // Scrolls, same as the real chip row — a fixed Row of these widths
      // doesn't fit narrower phones and overflows.
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final width in _widths) ...[
            ShimmerBone(width: width, height: 40, radius: 12),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// One category row, header plus a two-card peek of its grid — matches
/// `_HomeCategoryShelf` and [DishCard] closely enough that the swap-in feels
/// seamless rather than a different layout appearing underneath.
class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerBone(width: 46, height: 46, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBone(width: 130, height: 18),
                    SizedBox(height: 6),
                    ShimmerBone(width: 80, height: 12),
                  ],
                ),
              ),
              const ShimmerBone(width: 28, height: 14),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _DishCardSkeleton()),
              SizedBox(width: 14),
              Expanded(child: _DishCardSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}

class _DishCardSkeleton extends StatelessWidget {
  const _DishCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(aspectRatio: 1.10, child: ShimmerBone(radius: 0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBone(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  ShimmerBone(width: 60, height: 14),
                  SizedBox(height: 12),
                  ShimmerBone(width: double.infinity, height: 34, radius: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
