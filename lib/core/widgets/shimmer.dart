import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A soft highlight band that sweeps left to right, looping, over whatever
/// [child] paints — the shared "still loading" signal behind every skeleton
/// screen in the app, so individual bones don't need their own animation.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;

  /// What the child is tinted to outside the band, and at its brightest
  /// inside it. The defaults suit a skeleton bone sitting on white; a
  /// placeholder that already paints a grey field behind the child needs a
  /// base darker than that field or the child disappears into it.
  final Color? baseColor;
  final Color? highlightColor;

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
        final base = widget.baseColor ?? AppColors.divider;
        final highlight = widget.highlightColor ?? AppColors.white;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, highlight, base],
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
