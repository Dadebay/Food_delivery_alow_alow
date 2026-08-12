import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// A looping hero-video intro slide — the clip is supplied separately (drop a
/// file in at [videoAsset]); until then it falls back to a plain neutral card
/// so onboarding still runs and looks intentional, not broken. Same
/// muted/looping approach as [DeliveryLoader], just full-slide sized here.
///
/// Pass [videoAsset] for a slide with its own clip (this widget owns that
/// controller — creates it, plays it, disposes it). Pass [controller] instead
/// when several slides share one clip (pages 1 and 2 here): the caller owns
/// that controller's lifetime, so swiping between those slides only swaps the
/// caption underneath — the same decoder keeps playing, never restarts.
class OnboardingVideoPage extends StatefulWidget {
  const OnboardingVideoPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.videoAsset,
    this.controller,
    this.heightFraction,
  }) : assert(
         (videoAsset == null) != (controller == null),
         'Provide exactly one of videoAsset or controller',
       );

  final String? videoAsset;
  final VideoPlayerController? controller;
  final String title;
  final String subtitle;

  /// Fixes the video area to this fraction of the screen height instead of
  /// filling whatever space is left over. `null` keeps the old fill-the-rest
  /// behaviour.
  final double? heightFraction;

  @override
  State<OnboardingVideoPage> createState() => _OnboardingVideoPageState();
}

class _OnboardingVideoPageState extends State<OnboardingVideoPage> {
  late final VideoPlayerController _controller;
  late final bool _ownsController;
  bool _ready = false;

  /// >1 zooms in, cropping a bit more off every edge (left/right included);
  /// 1.0 = exactly `fitWidth`, no extra crop. Tweak this number to taste.
  static const double _zoom = 1.22;

  @override
  void initState() {
    super.initState();

    final sharedController = widget.controller;
    if (sharedController != null) {
      // Shared with another slide — someone else starts/stops/disposes it;
      // this instance only ever reads its state.
      _ownsController = false;
      _controller = sharedController;
      _ready = _controller.value.isInitialized;
      _controller.addListener(_handleControllerUpdate);
      return;
    }

    _ownsController = true;
    final controller = VideoPlayerController.asset(widget.videoAsset!)
      ..setLooping(true)
      ..setVolume(0);
    _controller = controller;

    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller.play();
          setState(() => _ready = true);
        })
        .catchError((Object _) {
          // Clip not dropped in yet (or failed to decode) — the fallback
          // tile below covers it, the slide still works.
          if (mounted) setState(() => _ready = false);
        });
  }

  void _handleControllerUpdate() {
    final initialized = _controller.value.isInitialized;
    if (initialized != _ready && mounted) setState(() => _ready = initialized);
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleControllerUpdate);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _ready
        ? Transform.scale(
            scale: _zoom,
            // Both crops anchor to the top edge rather than the centre —
            // centred cropping was cutting the first row of dishes in half
            // at the top; anchoring top keeps that row whole and trims the
            // bottom (and both sides evenly) instead.
            alignment: Alignment.topCenter,
            child: FittedBox(
              // Between cover (crops to fill both dimensions, can lose the
              // edges of the clip) and contain (never crops, but leaves
              // letterboxing on the sides) — fitWidth always fills edge to
              // edge horizontally and only crops top/bottom if it has to.
              // `_zoom` above adds extra crop on top of that, side included.
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height + 105,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        : Container(color: AppColors.divider);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // No horizontal padding here — the video runs edge to edge; only
          // the text below keeps a margin from the screen sides.
          if (widget.heightFraction != null)
            SizedBox(
              width: double.infinity,
              height:
                  MediaQuery.sizeOf(context).height * widget.heightFraction!,
              child: video,
            )
          else
            Expanded(child: video),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: AppText.h2.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
