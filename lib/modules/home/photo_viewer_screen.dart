import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/services/catalog_image_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';

/// Full-screen photo viewer: the dish's photos at their real aspect ratio,
/// pinch- and double-tap-zoomable.
///
/// The dish page crops its photos to a fixed band, which is right for a
/// header and wrong for actually looking at the food — so tapping one opens
/// it here, uncropped, on black.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<String> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            // Zooming in locks the pager: once a photo is magnified the
            // horizontal drag belongs to panning it, not to turning the page.
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.photos.length,
            itemBuilder: (context, i) => _ZoomablePhoto(url: widget.photos[i]),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
          if (widget.photos.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              right: 20,
              child: IgnorePointer(
                child: Text(
                  '${_index + 1} / ${widget.photos.length}',
                  style: AppText.body.copyWith(color: AppColors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One photo, pinch-zoomable and double-tap-zoomable.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.url});

  final String url;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  /// Built in [initState] rather than lazily: a `late final` field is only
  /// created on first read, and on a photo nobody double-tapped that first
  /// read is [dispose] itself — which then tries to look up the TickerMode
  /// of an element already being unmounted.
  late final AnimationController _animation;
  Animation<Matrix4>? _zoom;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _transform.dispose();
    _animation.dispose();
    super.dispose();
  }

  /// Double tap zooms to the point that was tapped, and a second one returns
  /// to fit — the gesture people expect from every other photo viewer.
  void _toggleZoom(TapDownDetails details) {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 end;
    if (zoomedIn) {
      end = Matrix4.identity();
    } else {
      const scale = 2.5;
      final position = details.localPosition;
      end = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    }
    _zoom = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    );
    _animation
      ..removeListener(_applyZoom)
      ..addListener(_applyZoom)
      ..forward(from: 0);
  }

  void _applyZoom() => _transform.value = _zoom!.value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _toggleZoom,
      // The handler lives on the down event so the tap position is known;
      // this one only exists to make the recognizer fire.
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(child: _Photo(url: widget.url)),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) {
      return Image.asset(url, fit: BoxFit.contain);
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: CatalogImageCacheManager.instance,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.white),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: HugeIcon(
          icon: AppIcons.foodWatermark,
          color: AppColors.white.withValues(alpha: 0.3),
          size: 64,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white.withValues(alpha: 0.16),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: HugeIcon(icon: AppIcons.cancel, color: AppColors.white, size: 18),
      ),
    ),
  );
}
