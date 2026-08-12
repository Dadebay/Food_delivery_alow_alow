import 'package:intl/intl.dart';

import '../constants/app_config.dart';

/// Money and distance formatting, matching the mock-ups.
class Fmt {
  const Fmt._();

  /// "139 TMT".
  static String money(double value) {
    final formatter = NumberFormat.decimalPattern('ru');
    final rounded = value == value.roundToDouble()
        ? formatter.format(value.round())
        : formatter.format(double.parse(value.toStringAsFixed(2)));
    return '$rounded ${AppConfig.currency}';
  }

  /// Bare amount, used inside "с 200".
  static String amount(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }

  /// "2,4 km".
  static String km(double? value) {
    if (value == null) return '—';
    if (value < 1) return '${(value * 1000).round()} m';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static String time(DateTime value) => DateFormat('HH:mm').format(value);

  static String date(DateTime value) => DateFormat('d MMM', 'ru').format(value);
}
