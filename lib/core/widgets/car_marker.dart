import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The courier's marker — a car in a white pill with a soft pulse, exactly as
/// in `courier_route.png` and `cust_track.png`. Same visual on the courier's
/// screen and the customer's, so it reads as the same person on both.
class CarMarker extends StatefulWidget {
  const CarMarker({super.key, this.heading = 0, this.size = 54});

  final double heading;
  final double size;

  @override
  State<CarMarker> createState() => _CarMarkerState();
}

class _CarMarkerState extends State<CarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              return Container(
                width: widget.size * (0.55 + 0.45 * t),
                height: widget.size * (0.55 + 0.45 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange.withValues(alpha: 0.18 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: widget.size * 0.62,
            height: widget.size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(color: AppColors.orange, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: (widget.heading - 90) * math.pi / 180,
                child: SvgPicture.asset(
                  'assets/icons/car_marker.svg',
                  width: widget.size * 0.36,
                  height: widget.size * 0.36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The branch the food is cooked at — the gold dot the route starts from.
class BranchMarker extends StatelessWidget {
  const BranchMarker({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// The customer's own delivery address — the panda mascot holding the
/// location pin (`assets/panda_pin.png`), rather than a plain glyph.
class DestinationPin extends StatelessWidget {
  const DestinationPin({super.key, this.size = 44});

  final double size;

  /// Total box height as a multiple of [size] — matches the artwork's own
  /// aspect ratio (898×859). Anything that needs to anchor the pin to an
  /// exact pixel (the address picker's fixed centre pin, the tracking map's
  /// `Marker.height`) must offset/size by `size * heightRatio`, not a
  /// hand-tuned constant, or it drifts off the actual point the moment this
  /// ratio changes.
  static const double heightRatio = 859 / 898;

  @override
  Widget build(BuildContext context) {
    // Kept inside the same size*heightRatio box the old hand-painted pin
    // used, anchored to its bottom edge. The pin the panda is holding sits
    // near the bottom-right of the artwork rather than dead-centre, so the
    // marked point is a few pixels off the pin's literal tip — an
    // acceptable trade for a mascot graphic rather than a symmetric glyph.
    return SizedBox(
      width: size,
      height: size * heightRatio,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          'assets/panda_pin.png',
          width: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
