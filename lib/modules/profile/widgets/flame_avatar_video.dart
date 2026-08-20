import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The looping flame clip shown in place of the default user glyph on the
/// identity card's avatar circle, for customers who haven't set a photo.
/// Same decode-locally/loop-in-place approach as `DeliveryLoader`, just
/// avatar-sized. Falls back to nothing while the clip decodes (or if it
/// fails to) so the white circle behind it still reads as an avatar.
///
/// The source clip is widescreen, so it is cropped into the avatar circle and
/// enlarged slightly. This keeps the panda's face legible at avatar size and
/// avoids exposing the video's rectangular white background.
class FlameAvatarVideo extends StatefulWidget {
  const FlameAvatarVideo({super.key, this.size = 40});

  final double size;

  static const String asset = 'assets/alev_alev.mp4';

  @override
  State<FlameAvatarVideo> createState() => _FlameAvatarVideoState();
}

class _FlameAvatarVideoState extends State<FlameAvatarVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(FlameAvatarVideo.asset)
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
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ColoredBox(
          color: Colors.white,
          child: _ready
              ? Transform.scale(
                  // The face sits at the centre of this 16:9 clip. Zooming
                  // makes it read as an avatar rather than a tiny full-body
                  // scene while ClipOval hides the cropped edges.
                  scale: 1.55,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
