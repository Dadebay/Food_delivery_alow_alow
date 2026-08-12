import 'package:flutter/material.dart';

/// Naharym palette — green leads (the app bar, the selected nav tab, focus
/// states), orange is the vibrant accent used alongside it (primary buttons,
/// discount badges, the cart bar). Orange's exact shade is sampled from the
/// app icon; everything else from the approved mock-ups
/// (`Naharym-mockups-RU/cust_home.png`, `cust_cart.png`, `cust_track.png`).
class AppColors {
  const AppColors._();

  static const Color green = Color(0xFF0B3B2E);
  static const Color greenLight = Color(0xFF1D6B50);
  static const Color greenMuted = Color(0xFF8FB0A2);
  static const Color greenSurface = Color(0xFF11493A);

  /// Accent colour — sampled from the app icon. Primary buttons, discount
  /// badges, the cart bar, "Заказать".
  static const Color orange = Color(0xFFF2761D);
  static const Color orangeSoft = Color(0xFFFFEDE6);

  /// Money, change-due notes.
  static const Color gold = Color(0xFFC8A24A);
  static const Color goldSoft = Color(0xFFF3E7C9);

  static const Color red = Color(0xFFC84833);
  static const Color redSoft = Color(0xFFFBE7E3);

  static const Color cream = Color(0xFFfef2e1);
  static const Color white = Color(0xFFFFFFFF);

  /// Neutral light grey — matches the food-gallery onboarding clip's own
  /// background, so the scaffold behind it doesn't read as a slightly
  /// different white next to the video.
  static const Color neutralGrey = Color(0xFFf7fcfa);

  /// Matches the baked background of the delivery-loader video, so it blends
  /// into the loading page instead of appearing as a visible rectangle.
  static const Color loaderBackground = Color(0xFFF7F7F7);

  static const Color textPrimary = Color(0xFF16211D);
  static const Color textSecondary = Color(0xFF6B7B75);
  static const Color textMuted = Color(0xFFA6B2AD);
  static const Color divider = Color(0xFFE8E2D6);

  static const Color shadow = Color(0x14000000);
}
