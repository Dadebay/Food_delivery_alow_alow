import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A "show more / show less" row.
///
/// Deliberately a plain text row rather than a button: it is a disclosure,
/// not an action, and a filled button would compete with the real one on the
/// screen — "Save" on the address form, the courier's call button on the
/// tracking sheet.
class DetailsToggle extends StatelessWidget {
  const DetailsToggle({
    super.key,
    required this.expanded,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              label,
              style: AppText.body.copyWith(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            // Rotates instead of swapping glyphs, so the open and closed
            // states read as one control rather than two.
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: expanded ? 0.5 : 0,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
