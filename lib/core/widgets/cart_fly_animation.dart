import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plays a "flies into the cart" flourish from wherever a dish was added,
/// arcing up to the cart tab's real on-screen position. Purely visual — the
/// actual add-to-cart call happens at the call site; this just gives it a
/// satisfying finish.
class CartFlyAnimation {
  CartFlyAnimation._();

  /// Attach to whatever marks the cart tab's on-screen position (see
  /// `AnimatedBottomNavBar`'s cart item) — the fly target is read from its
  /// RenderBox.
  static final GlobalKey cartIconKey = GlobalKey();

  /// [imageUrl] follows the same convention as [Dish.imageUrl] — an asset
  /// path or a network URL, or `null`/empty for the fallback bag glyph.
  static ImageProvider? imageFor(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    return imageUrl.startsWith('http')
        ? CachedNetworkImageProvider(imageUrl)
        : AssetImage(imageUrl);
  }

  /// Finds [fromContext]'s own on-screen centre and flies from there — call
  /// this with the tapped button's context, no manual position math needed.
  static void runFrom({required BuildContext fromContext, String? imageUrl}) {
    final box = fromContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    run(
      context: fromContext,
      startCenter: box.localToGlobal(box.size.center(Offset.zero)),
      imageUrl: imageUrl,
    );
  }

  static void run({
    required BuildContext context,
    required Offset startCenter,
    String? imageUrl,
  }) {
    final cartCtx = cartIconKey.currentContext;
    if (cartCtx == null) return;
    final box = cartCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final endCenter = box.localToGlobal(box.size.center(Offset.zero));
    final overlayState = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyingItem(
        start: startCenter,
        end: endCenter,
        onCompleted: () => entry.remove(),
        child: _FlyingThumb(image: imageFor(imageUrl)),
      ),
    );
    overlayState.insert(entry);
  }
}

class _FlyingThumb extends StatelessWidget {
  const _FlyingThumb({this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: AppColors.orange, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
        ],
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? const Icon(
              Icons.shopping_bag_rounded,
              color: AppColors.orange,
              size: 18,
            )
          : null,
    );
  }
}

class _FlyingItem extends StatefulWidget {
  const _FlyingItem({
    required this.start,
    required this.end,
    required this.child,
    required this.onCompleted,
  });

  final Offset start;
  final Offset end;
  final Widget child;
  final VoidCallback onCompleted;

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInCubic);
    _controller.forward().whenComplete(widget.onCompleted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        final dx = ui.lerpDouble(widget.start.dx, widget.end.dx, t)!;
        final baseY = ui.lerpDouble(widget.start.dy, widget.end.dy, t)!;
        // Upward arc (parabola) — the flight bulges up in the middle rather
        // than cutting a straight line to the cart tab.
        final arcBulge = 130 * t * (1 - t);
        final dy = baseY - arcBulge;
        final scale = ui.lerpDouble(1.0, 0.25, t)!;
        final opacity = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);

        return Positioned(
          left: dx - 21,
          top: dy - 21,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
