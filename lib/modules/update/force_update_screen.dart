import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

/// The wall a build below `minSupportedVersion` hits.
///
/// Nothing here navigates anywhere. There is no back gesture, no "later", no
/// close button — the whole point is that this build can no longer talk to
/// the backend correctly, so letting the customer past it would only hand
/// them a broken app and a support call. The support number is the one way
/// out, because a customer who genuinely cannot reach the store needs a
/// human, not a dead end.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final update = context.watch<AppUpdateService>();
    final notes = update.info?.releaseNotes(
      context.watch<LocaleProvider>().locale.languageCode,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.green,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Column(
              children: [
                const Spacer(),
                const _UpdateGlyph(),
                const SizedBox(height: 32),
                Text(
                  s.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: AppText.h1.copyWith(fontSize: 28, height: 1.25),
                ),
                const SizedBox(height: 14),
                Text(
                  s.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: AppColors.cream,
                    height: 1.5,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _ReleaseNotes(text: notes),
                ],
                const Spacer(),
                AppButton(
                  label: s.updateNow,
                  onPressed: () => _openStore(context, s.updateStoreFailed),
                ),
                const SizedBox(height: 14),
                _SupportRow(
                  label: s.updateNeedHelp,
                  phone: AppConfig.supportPhone,
                ),
                const SizedBox(height: 10),
                // Quiet, but present: the first thing support will ask is
                // which version the customer is on.
                Text(
                  s.updateCurrentVersion(update.currentVersion),
                  style: AppText.bodyMuted.copyWith(
                    fontSize: 12,
                    color: AppColors.greenMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String failureMessage) async {
    final opened = await context.read<AppUpdateService>().openStore();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}

/// A ring around the arrow rather than a bare icon — on a flat brand-coloured
/// screen a lone glyph reads as an error state, and this is not an error.
class _UpdateGlyph extends StatelessWidget {
  const _UpdateGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.orange,
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedDownload04,
            color: AppColors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: AppColors.cream, fontSize: 13),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.label, required this.phone});

  final String label;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppText.bodyMuted.copyWith(color: AppColors.greenMuted),
        ),
        const SizedBox(width: 6),
        Text(
          phone,
          style: AppText.body.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
