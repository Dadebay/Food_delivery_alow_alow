import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../shell/main_nav_screen.dart';
import 'onboarding_provider.dart';
import 'widgets/onboarding_video_page.dart';

/// First-launch intro, three looping-video slides — the clips are supplied
/// separately (see `OnboardingVideoPage`). Language is picked on its own
/// screen before this one runs (see `language_select_screen.dart`), so
/// onboarding never needs to ask for it. Shown once — [OnboardingProvider]
/// remembers it's done.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 3;

  /// Pages 1 and 2 show the same clip — one controller, shared, so pressing
  /// "Далее" between them only swaps the caption text underneath. The video
  /// itself keeps playing without a hitch instead of a second decoder
  /// cold-starting the instant that slide comes into view.
  late final VideoPlayerController _foodVideo;

  @override
  void initState() {
    super.initState();
    _foodVideo =
        VideoPlayerController.asset(
            'assets/animations/onboarding/onboarding_1.mp4',
          )
          ..setLooping(true)
          ..setVolume(0);
    _foodVideo.initialize().then((_) {
      if (mounted) _foodVideo.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _foodVideo.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<OnboardingProvider>().complete();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainNavScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final onLastPage = _page == _pageCount - 1;
    // The first two slides are the food-gallery clip, which is shot on a
    // light grey, not pure white — matching that here means there's no seam
    // where the clip ends and the page background begins. The courier slide
    // keeps the app's usual cream.
    final pageBackground = _page < 2 ? AppColors.neutralGrey : AppColors.cream;

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  OnboardingVideoPage(
                    controller: _foodVideo,
                    title: s.onboardingTitle1,
                    subtitle: s.onboardingSubtitle1,
                    heightFraction: 0.5,
                  ),
                  OnboardingVideoPage(
                    controller: _foodVideo,
                    title: s.onboardingTitle2,
                    subtitle: s.onboardingSubtitle2,
                    heightFraction: 0.5,
                  ),
                  OnboardingVideoPage(
                    videoAsset: 'assets/animations/onboarding/onboarding_3.mp4',
                    title: s.onboardingCourierTitle,
                    subtitle: s.onboardingCourierSubtitle,
                  ),
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
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        _Dot(active: i == _page),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: onLastPage ? s.onboardingStart : s.onboardingNext,
                    onPressed: _next,
                  ),
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
      decoration: BoxDecoration(
        color: active ? AppColors.orange : AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
