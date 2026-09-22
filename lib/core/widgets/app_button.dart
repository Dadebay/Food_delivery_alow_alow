import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';

/// Full-width action button. Big hit area on purpose — couriers tap these one
/// handed, standing next to a car.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.brand,
    this.textColor = AppColors.onBrand,
    this.outlined = false,
    this.busy = false,
    this.icon,
    this.leading,
    this.height = 56,
  });

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.leading,
    this.height = 56,
  }) : color = AppColors.divider,
       textColor = AppColors.onBrand,
       outlined = true;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool outlined;
  final bool busy;
  final HugeIconData? icon;

  /// Overrides [icon] with an arbitrary widget (e.g. a looping video icon)
  /// when set — same slot, same spacing.
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return SizedBox(
      height: height,
      child: Material(
        color: outlined ? AppColors.white : color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: outlined
                  ? Border.all(color: AppColors.divider, width: 1.5)
                  : null,
              color: enabled
                  ? null
                  // Dim rather than grey out — the label must stay readable
                  // in direct sunlight.
                  : (outlined ? null : color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(textColor),
                      ),
                    )
                  : Padding(
                      // Keeps the label off the rounded corners when the
                      // button is narrow — two of them side by side in a
                      // dialog, for instance.
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 10),
                          ] else if (icon != null) ...[
                            HugeIcon(icon: icon!, size: 20, color: textColor),
                            const SizedBox(width: 10),
                          ],
                          // A long label (a translation, a two-word action)
                          // shrinks to fit rather than overflowing: the whole
                          // word still reads, just a shade smaller.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                style: AppText.button.copyWith(color: textColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
