import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Image.asset('assets/logo_text.png', height: 160),
              const Spacer(flex: 1),
              Padding(padding: const EdgeInsets.only(right: 25), child: Image.asset('assets/logo_icon.png', height: 220)),
              const Spacer(flex: 2),
              Text(
                s.chooseLanguage,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(fontSize: 24, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final option in LocaleProvider.supported)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _LanguageCard(strings: option, selected: option.languageCode == _selected.languageCode, onTap: () => setState(() => _selected = option)),
                      ),
                    ),
                ],
              ),
              const Spacer(flex: 3),
              AppButton(label: s.onboardingNext, onPressed: () => context.read<LocaleProvider>().select(_selected)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.strings, required this.selected, required this.onTap});

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
            border: selected ? null : Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Center(
            child: Text(strings.languageName, style: AppText.button.copyWith(fontSize: 15, color: selected ? AppColors.white : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}
