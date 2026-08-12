import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A soft highlight band that sweeps left to right, looping, over whatever
/// [child] paints — the shared "still loading" signal behind every skeleton
/// screen in the app, so individual bones don't need their own animation.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              AppColors.divider,
              AppColors.white,
              AppColors.divider,
            ],
            stops: const [0.35, 0.5, 0.65],
            // The band sweeps fully off-canvas to fully off-canvas the other
            // side each cycle, so it enters and exits cleanly at the edges.
            begin: Alignment(-2 + 4 * t, 0),
            end: Alignment(-1 + 4 * t, 0),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// One skeleton block — a flat, rounded tile standing in for text, a
/// thumbnail, or a whole card until the real content is ready.
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({super.key, this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
