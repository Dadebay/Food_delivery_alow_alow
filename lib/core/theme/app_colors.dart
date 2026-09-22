import 'package:flutter/material.dart';

/// Naharym palette — green leads (the app bar, the selected nav tab, focus
/// states), orange is the vibrant accent used alongside it (primary buttons,
/// discount badges, the cart bar). Orange's exact shade is sampled from the
/// app icon; everything else from the approved mock-ups
/// (`Naharym-mockups-RU/cust_home.png`, `cust_cart.png`, `cust_track.png`).
class AppColors {
  const AppColors._();

  /// The brand surface — the app bar, the bottom bar, primary buttons.
  ///
  /// Yellow, the way the big delivery apps use it (Yandex Eats, McDonald's):
  /// warm and impossible to miss. Unlike the dark surface it replaces, it
  /// carries *dark* text — white on yellow is unreadable — so anything drawn
  /// on top of it uses [onBrand] rather than [white].
  static const Color brand = Color(0xFFFCE000);
  static const Color brandLight = Color(0xFFFFF04D);
  static const Color brandSurface = Color(0xFFF0D200);

  /// Text and icons on [brand]. Near-black rather than pure black so it sits
  /// on yellow without the hard edge full black gives.
  static const Color onBrand = Color(0xFF1B1A17);

  /// A dimmed ink for secondary labels on the brand surface — the yellow
  /// equivalent of a muted grey on white.
  static const Color brandMuted = Color(0xFF7A7048);

  /// Accent colour — sampled from the app icon. Primary buttons, discount
  /// badges, the cart bar, "Заказать".
  static const Color orange = Color(0xFFF2761D);
  static const Color orangeSoft = Color(0xFFFFEDE6);

  /// The yellow half of the pair — badges, money, highlights on light
  /// surfaces. Never used for small text or thin icons: yellow on white has
  /// too little contrast to read, which is why the accent that has to carry
  /// labels stays [orange].
  static const Color gold = Color(0xFFFFC72C);
  static const Color goldSoft = Color(0xFFFFF1CC);

  /// Errors and destructive actions. Deliberately a deeper, browner red than
  /// [brand] so "this is the app" and "this went wrong" stay distinguishable
  /// now that the brand itself is red.
  /// Success — a cooked or delivered order.
  ///
  /// Green outlived the palette change on purpose: it is the one colour a
  /// customer reads as "done" without a label, and the brand yellow cannot
  /// carry that meaning now that it means "the app" instead.
  static const Color success = Color(0xFF1E8E4E);
  static const Color successSoft = Color(0xFFE3F0E9);

  /// Ink for labels on [goldSoft] — the yellow itself is far too pale to
  /// read as text on its own tint.
  static const Color goldInk = Color(0xFF8A6400);

  static const Color red = Color(0xFF8E1B12);
  static const Color redSoft = Color(0xFFFBE7E3);

  /// The warm page surface. Pushed further towards yellow so the app reads
  /// as red-and-yellow at a glance rather than red on plain white.
  static const Color cream = Color(0xFFFFF3D6);
  static const Color white = Color(0xFFFFFFFF);

  /// Matches the baked-in background of the onboard*.png illustrations —
  /// language select and the onboarding slides.
  static const Color onboardingBackground = Color(0xFFFCF5EB);

  /// Neutral light grey — matches the food-gallery onboarding clip's own
  /// background, so the scaffold behind it doesn't read as a slightly
  /// different white next to the video.
  static const Color neutralGrey = Color(0xFFFFFBF2);

  /// Matches the baked background of the delivery-loader video, so it blends
  /// into the loading page instead of appearing as a visible rectangle.
  static const Color loaderBackground = Color(0xFFF7F7F7);

  /// Near-black with a warm cast rather than the old green one, so text sits
  /// on the cream surfaces without looking cold against them.
  static const Color textPrimary = Color(0xFF211714);
  static const Color textSecondary = Color(0xFF7A6660);
  static const Color textMuted = Color(0xFFB3A39D);
  static const Color divider = Color(0xFFEFE2CE);

  static const Color shadow = Color(0x14000000);
}
