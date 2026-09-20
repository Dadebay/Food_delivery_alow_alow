import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The two states of the heart, as drawn assets.
///
/// These SVGs carry their own colours *and* a white outer halo, so they stay
/// legible straight on top of a dish photo — no tinting and no disc behind
/// them required. That's also why they're assets rather than an icon font:
/// the filled and the empty heart are genuinely different drawings, not the
/// same glyph in two colours.
class FavoriteGlyph extends StatelessWidget {
  const FavoriteGlyph({super.key, required this.active, required this.size});

  final bool active;
  final double size;

  static const _full = 'assets/icons/favorite_full.svg';
  static const _empty = 'assets/icons/favorite_empty.svg';

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    active ? _full : _empty,
    width: size,
    height: size,
  );
}

/// The heart used on a dish card and its detail screen.
class FavoriteToggle extends StatelessWidget {
  const FavoriteToggle({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 22,
    this.background,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  /// Overrides the disc behind the glyph. Left unset, the empty heart gets a
  /// white one — its own fill is white and its outline grey, which vanishes
  /// against a pale dish photo — while the filled heart, red and unmistakable
  /// on anything, keeps the photo showing through.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          background ??
          (active ? Colors.transparent : AppColors.white.withValues(alpha: 0.92)),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Tight on the glyph — the disc is there to lift the outline off
          // the photo, not to be a button of its own.
          padding: const EdgeInsets.all(3),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Only present while active, so it's built fresh — and
                // plays once — every time the heart turns on, rather than
                // replaying on unrelated rebuilds.
                if (active)
                  TweenAnimationBuilder<double>(
                    key: const ValueKey('burst'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOut,
                    builder: (context, t, child) => Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(scale: 1 + t * 1.6, child: child),
                    ),
                    child: FavoriteGlyph(active: true, size: size),
                  ),
                TweenAnimationBuilder<double>(
                  // Re-keying on the state restarts the pop every time it
                  // flips.
                  key: ValueKey(active),
                  tween: Tween(begin: active ? 1.35 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: FavoriteGlyph(active: active, size: size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
