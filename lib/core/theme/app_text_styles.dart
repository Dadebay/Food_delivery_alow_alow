import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gilroy throughout — same family as the courier app and the rest of the
/// Naharym surfaces.
class AppText {
  const AppText._();

  static const String family = 'Gilroy';

  /// Display face reserved for the brand wordmark on loading placeholders.
  /// Deliberately outside the scale below, so nothing inherits it by
  /// accident.
  static const String wordmarkFamily = 'Qurova';

  /// Screen titles, dish name on its detail sheet.
  ///
  /// Ink rather than white: this style was written for the dark brand bar,
  /// and that bar is yellow now. The few places that still sit on something
  /// dark pass their own colour.
  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.onBrand,
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
