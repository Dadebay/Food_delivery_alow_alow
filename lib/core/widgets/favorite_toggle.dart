import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// The heart used on a dish card and its detail screen.
///
/// HugeIcons only ships this app's stroke (outline) style — there's no
/// filled companion glyph — so favoriting swaps to Material's built-in
/// solid heart instead of just recolouring the same outline. That's the
/// "did it register" signal outline-plus-colour alone doesn't give.
class FavoriteToggle extends StatelessWidget {
  const FavoriteToggle({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 18,
    this.background,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  /// Defaults to a near-opaque white disc — reads as glass sitting on a
  /// photo without punching a solid hole in it.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? AppColors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
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
                      child: Transform.scale(
                        scale: 1 + t * 1.6,
                        child: Icon(
                          Icons.favorite,
                          color: AppColors.orange,
                          size: size,
                        ),
                      ),
                    ),
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
                  child: active
                      ? Icon(
                          Icons.favorite,
                          color: AppColors.orange,
                          size: size,
                        )
                      : HugeIcon(
                          icon: AppIcons.favorite,
                          color: AppColors.textMuted,
                          size: size,
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
