import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// The app's loading animation — the courier clip, looping.
///
/// An animated WebP with a transparent background, decoded and looped by
/// Flutter's own image pipeline. It was an MP4 played through `video_player`,
/// which worked but could only ever draw an opaque rectangle: H.264 has no
/// alpha channel, so the clip's own flat #F5F5F5 field was baked into every
/// frame and showed as a grey box behind the drawing on every screen that
/// used it. WebP carries alpha, so the artwork now sits directly on whatever
/// is behind it.
///
/// The clip is also cropped to the drawing itself — the source frames were
/// 800x600 with the art occupying a 247px square in the middle, so most of
/// what the widget reserved was empty grey. Nothing is downloaded and it
/// keeps working with no connection, as before.
class DeliveryLoader extends StatelessWidget {
  const DeliveryLoader({super.key, this.size = 200, this.message});

  /// Width of the animation. The clip is square, so this is its height too.
  final double size;

  /// Optional caption underneath.
  final String? message;

  static const String asset = 'assets/animations/delivery_loader.webp';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          // A decode failure must not take the screen down with it — the
          // caption and the layout stay, the animation simply does not
          // appear, and the slot keeps its size so nothing jumps.
          errorBuilder: (context, error, stackTrace) =>
              SizedBox(width: size, height: size),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
        ],
      ],
    );
  }
}
