import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/models/promotion_banner.dart';
import '../../catalog/catalog_provider.dart';
import '../dish_detail_screen.dart';
import '../../category/category_dishes_screen.dart';

/// Swipeable, auto-advancing carousel of partner promo images at the top of
/// the home feed, built on `carousel_slider` rather than a hand-rolled
/// PageView + Timer, with `flutter_animate` for the entrance/indicator
/// motion. Any image that fails to load (asset not dropped in yet) falls
/// back to a plain colour tile instead of throwing.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners, this.height = 240, this.horizontalPadding = 10});

  final List<PromotionBanner> banners;
  final double height;
  final double horizontalPadding;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: widget.height,
            viewportFraction: 1,
            autoPlay: widget.banners.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayCurve: Curves.easeInOutCubic,
            autoPlayAnimationDuration: const Duration(milliseconds: 700),
            onPageChanged: (index, _) => setState(() => _page = index),
          ),
          items: [
            for (final banner in widget.banners)
              // Each slide carries its own side margin — otherwise, at
              // viewportFraction 1, the outgoing and incoming banners
              // touch edge-to-edge mid-swipe with no gap between them.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding, vertical: 18),

                child: Material(
                  elevation: 10,
                  shadowColor: AppColors.green.withValues(alpha: 0.22),
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: banner.link == null ? null : () => _openTarget(context, banner.link!),
                    child: _BannerImage(banner: banner),
                  ),
                ),
              ),
          ],
        ).animate().fadeIn(duration: 450.ms, curve: Curves.easeOut).scaleXY(begin: 0.94, end: 1, duration: 450.ms, curve: Curves.easeOut),
        if (widget.banners.length > 1) ...[const SizedBox(height: 10), _DotsIndicator(count: widget.banners.length, activeIndex: _page)],
      ],
    );
  }
}

Future<void> _openTarget(BuildContext context, String rawLink) async {
  final uri = Uri.tryParse(rawLink);
  if (uri == null) return;
  // Internal targets can be configured in admin as app://product/<uuid> or
  // app://category/<uuid>. Normal web links retain their existing behavior.
  if ((uri.scheme == 'app' || uri.scheme == 'alowalow') && uri.pathSegments.isNotEmpty) {
    final id = uri.pathSegments.first;
    final catalog = context.read<CatalogProvider>();
    if (uri.host == 'product') {
      final matches = catalog.dishes.where((dish) => dish.id == id);
      if (matches.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DishDetailScreen(dish: matches.first)));
      }
      return;
    }
    if (uri.host == 'category') {
      final matches = catalog.categories.where((category) => category.id == id);
      if (matches.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryDishesScreen(categoryId: matches.first.id, categoryName: matches.first.name),
          ),
        );
      }
      return;
    }
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.banner});

  final PromotionBanner banner;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.greenSurface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Text(
        banner.title,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.green),
      ),
    );
    if (banner.imageUrl.startsWith('assets/')) {
      return Image.asset(banner.imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => fallback);
    }
    return Image.network(banner.imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => fallback);
  }
}

/// Same fluid-pill trick as [AnimatedBottomNavBar]: fixed-size dots sit still
/// underneath, and one active pill glides between their slots on top —
/// `AnimatedPositioned` sliding with an overshoot-then-settle curve, instead
/// of every dot resizing itself in place.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  static const _slotWidth = 18.0;
  static const _dotWidth = 6.0;
  static const _pillWidth = 20.0;
  static const _dotHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _slotWidth * count,
      height: _dotHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: _slotWidth,
                  height: _dotHeight,
                  child: Center(
                    child: Container(
                      width: _dotWidth,
                      height: _dotWidth,
                      decoration: const BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            left: _slotWidth * activeIndex + (_slotWidth - _pillWidth) / 2,
            top: 0,
            width: _pillWidth,
            height: _dotHeight,
            // Re-keying on the index restarts the pop-in scale every time the
            // pill lands on a new dot, same as the nav bar's tab pill.
            child: _Pill(key: ValueKey(activeIndex)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
