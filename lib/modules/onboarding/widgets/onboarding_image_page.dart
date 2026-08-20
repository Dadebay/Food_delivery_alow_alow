import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// A single onboarding slide — full-bleed illustration on top (the artwork
/// already bakes in its own cream background, food photos, and dish labels;
/// see `assets/onboard*.png`), title/subtitle below.
class OnboardingImagePage extends StatelessWidget {
  const OnboardingImagePage({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.subtitle,
  });

  final String imageAsset;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imageAsset,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              // Where the cover-fit crop lands on the illustration's baked
              // background varies by screen aspect ratio, so the exact seam
              // between it and the scaffold below can't be baked into the
              // PNG itself — faded here instead, always landing exactly on
              // whatever got cropped.
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00FCF5EB),
                        AppColors.onboardingBackground,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.h2.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppText.bodyMuted.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
