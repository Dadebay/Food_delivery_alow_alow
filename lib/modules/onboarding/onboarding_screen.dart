import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import 'onboarding_provider.dart';
import 'widgets/onboarding_image_page.dart';

/// First-launch intro, three illustrated slides (see `assets/onboard*.png`).
/// Language is picked on its own screen before this one runs (see
/// `language_select_screen.dart`), so onboarding never needs to ask for it.
/// Shown once — [OnboardingProvider] remembers it's done.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<OnboardingProvider>().complete();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final onLastPage = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  OnboardingImagePage(imageAsset: 'assets/onboard1.png', title: s.onboardingTitle1, subtitle: s.onboardingSubtitle1),
                  OnboardingImagePage(imageAsset: 'assets/onboard2.png', title: s.onboardingTitle2, subtitle: s.onboardingSubtitle2),
                  OnboardingImagePage(imageAsset: 'assets/onboard3.png', title: s.onboardingCourierTitle, subtitle: s.onboardingCourierSubtitle),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (var i = 0; i < _pageCount; i++) _Dot(active: i == _page)],
                  ),
                  const SizedBox(height: 20),
                  AppButton(label: onLastPage ? s.onboardingStart : s.onboardingNext, onPressed: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(color: active ? AppColors.orange : AppColors.divider, borderRadius: BorderRadius.circular(4)),
    );
  }
}
