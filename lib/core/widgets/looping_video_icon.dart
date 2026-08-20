import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A small looping, muted clip used in place of a static icon — same
/// decode-locally/loop-in-place approach as [DeliveryLoader], just
/// icon-sized. Renders nothing while the clip decodes (or if it fails to),
/// so the surrounding layout never jumps.
class LoopingVideoIcon extends StatefulWidget {
  const LoopingVideoIcon({
    super.key,
    required this.asset,
    this.size = 22,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final double size;
  final BoxFit fit;

  @override
  State<LoopingVideoIcon> createState() => _LoopingVideoIconState();
}

class _LoopingVideoIconState extends State<LoopingVideoIcon> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset)
      ..setLooping(true)
      ..setVolume(0);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.play();
          setState(() => _ready = true);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _ready = false);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _ready
          ? FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
