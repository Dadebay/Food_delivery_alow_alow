import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

/// The polite half of the update flow: a newer build exists, but this one
/// still works.
///
/// Shown at most once per launch and dismissible every way a sheet can be —
/// the button, the barrier, the drag. An optional update that nags is how
/// customers learn to ignore the required one.
Future<void> showOptionalUpdateSheet(BuildContext context) async {
  final update = context.read<AppUpdateService>();
  if (!update.shouldPromptOptional) return;
  update.dismissOptional();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _OptionalUpdateSheet(),
  );
}

class _OptionalUpdateSheet extends StatelessWidget {
  const _OptionalUpdateSheet();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final update = context.read<AppUpdateService>();
    final notes = update.info?.releaseNotes(
      context.watch<LocaleProvider>().locale.languageCode,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeSoft,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload04,
                color: AppColors.orange,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              s.updateAvailableTitle,
              textAlign: TextAlign.center,
              style: AppText.h1.copyWith(
                fontSize: 21,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notes == null || notes.isEmpty ? s.updateAvailableBody : notes,
              textAlign: TextAlign.center,
              style: AppText.bodyMuted.copyWith(height: 1.45),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: s.updateNow,
              onPressed: () {
                Navigator.of(context).pop();
                update.openStore();
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                s.updateLater,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
