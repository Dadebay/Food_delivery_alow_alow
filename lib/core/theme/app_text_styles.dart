import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gilroy throughout — same family as the courier app and the rest of the
/// Naharym surfaces.
class AppText {
  const AppText._();

  static const String family = 'Gilroy';

  /// Screen titles, dish name on its detail sheet.
  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    height: 1.15,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle figure = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  /// Small upper-case labels — "АДРЕС ДОСТАВКИ", "SARGYT".
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 1.1,
    height: 1.2,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
