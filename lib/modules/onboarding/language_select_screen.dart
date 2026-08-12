import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

/// Stand-alone first screen — not one of the onboarding slides, and not
/// swipeable alongside them. The very first thing the app asks, before
/// anything else (including the onboarding copy itself) renders in a
/// language the customer may not have picked yet.
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late AppStrings _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<LocaleProvider>().strings;
  }

  @override
  Widget build(BuildContext context) {
    // Not `context.s` — this screen must read sensibly before any language
    // has actually been chosen, using whatever `_selected` currently is.
    final s = _selected;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orangeSoft,
                  border: Border.all(color: AppColors.orange, width: 2),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: AppIcons.cart,
                    color: AppColors.orange,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                s.chooseLanguage,
                style: AppText.h1.copyWith(
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  for (final option in LocaleProvider.supported)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _LanguageCard(
                          strings: option,
                          selected:
                              option.languageCode == _selected.languageCode,
                          onTap: () => setState(() => _selected = option),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              AppButton(
                label: s.onboardingNext,
                onPressed: () =>
                    context.read<LocaleProvider>().select(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Center(
            child: Text(
              strings.languageName,
              style: AppText.button.copyWith(
                fontSize: 15,
                color: selected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
