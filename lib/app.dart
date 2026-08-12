import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/analytics_service.dart';
import 'modules/onboarding/language_select_screen.dart';
import 'modules/onboarding/onboarding_provider.dart';
import 'modules/onboarding/onboarding_screen.dart';
import 'modules/shell/main_nav_screen.dart';

class FoodDeliveryApp extends StatelessWidget {
  const FoodDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'Naharym',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale.locale,
      supportedLocales: const [Locale('ru'), Locale('tk'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Turkmen has no Material translations upstream; fall back to Russian
      // for the framework's own strings rather than English.
      localeResolutionCallback: (deviceLocale, supported) =>
          locale.locale.languageCode == 'tk'
          ? const Locale('ru')
          : locale.locale,
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
      navigatorObservers: [
        FirebaseAnalyticsObserver(
          analytics: AnalyticsService.instance.analytics,
        ),
      ],
      // Browsing the menu and building a cart never requires an account —
      // sign-in is only asked for at the point it actually matters: placing
      // an order (see `CartScreen._goToCheckout`).
      home: const _Root(),
    );
  }
}

/// First launch only, in order: pick a language (its own screen, not tied to
/// onboarding), then the onboarding slides, then straight to the menu on
/// every launch after that.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    if (!locale.hasChosen) return const LanguageSelectScreen();

    final onboarding = context.watch<OnboardingProvider>();
    return onboarding.seen ? const MainNavScreen() : const OnboardingScreen();
  }
}
