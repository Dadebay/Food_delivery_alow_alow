import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';

/// How loudly a message should read.
enum AppSnackKind {
  /// Something the customer has to fix before they can carry on — a missing
  /// address, an unfinished field. Not a failure, so it is amber rather than
  /// red: red is for things that went wrong, and nothing has yet.
  warning,

  /// A request failed.
  error,

  /// Worked.
  success,
}

/// The app's one snack bar.
///
/// Flutter's default is a grey slab with the text jammed against the edge and
/// an action that looks like plain text. This gives a message the same
/// vocabulary as the rest of the app: a tinted glyph so the kind is readable
/// before the sentence is, generous spacing, and an action shaped like a
/// button so it is obvious it can be tapped.
abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackKind kind = AppSnackKind.warning,
    String? actionLabel,
    VoidCallback? onAction,
    HugeIconData? icon,
  }) {
    final accent = _accent(kind);
    ScaffoldMessenger.of(context)
      // Tapping a disabled-looking button twice should not stack two
      // identical messages.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.green,
          elevation: 8,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  // A flat tint of the accent rather than the accent itself:
                  // a solid orange disc next to white text is louder than the
                  // message deserves.
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon ?? _icon(kind),
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppText.body.copyWith(
                    color: AppColors.white,
                    height: 1.35,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                _Action(label: actionLabel, accent: accent, onTap: onAction),
              ],
            ],
          ),
        ),
      );
  }

  static Color _accent(AppSnackKind kind) => switch (kind) {
    AppSnackKind.warning => AppColors.gold,
    AppSnackKind.error => AppColors.orange,
    AppSnackKind.success => AppColors.greenLight,
  };

  static HugeIconData _icon(AppSnackKind kind) => switch (kind) {
    AppSnackKind.warning => AppIcons.info,
    AppSnackKind.error => AppIcons.cancel,
    AppSnackKind.success => AppIcons.checkCircle,
  };
}

/// Shaped like a button because it behaves like one — the stock
/// [SnackBarAction] is bare text and reads as part of the sentence.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: AppText.body.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
