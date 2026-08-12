import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';

/// One tab's icon, label, and optional badge count (e.g. cart item count).
class NavBarItemData {
  const NavBarItemData({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final HugeIconData icon;
  final String label;
  final int badgeCount;
}

/// A hand-rolled replacement for [BottomNavigationBar]: a green pill slides
/// between tabs on selection, the active icon pops with a small bounce, and
/// cart badges scale in — no extra package, just implicit Flutter animations.
class AnimatedBottomNavBar extends StatelessWidget {
  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<NavBarItemData> items;
  final ValueChanged<int> onTap;

  static const _height = 64.0;
  static const _margin = 6.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _margin,
              vertical: _margin,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      top: 0,
                      bottom: 0,
                      left: itemWidth * currentIndex,
                      width: itemWidth,
                      // Re-keying on the index restarts the pill's own pop-in
                      // animation every time it lands on a new tab, on top of
                      // the slide overshooting past its target and settling
                      // back — that combination is what reads as a bounce.
                      child: _Pill(key: ValueKey(currentIndex)),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavItem(
                              data: items[i],
                              active: i == currentIndex,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final NavBarItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.white : AppColors.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(active),
                tween: Tween(begin: active ? 0.7 : 1, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: HugeIcon(icon: data.icon, color: color, size: 22),
              ),
              if (data.badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: _Badge(count: data.badgeCount),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1.3,
            ),
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 16),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Gilroy',
            color: AppColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
