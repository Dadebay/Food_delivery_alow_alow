import 'package:flutter/widgets.dart';

/// Layout rules for screens wider than a phone.
///
/// The app was drawn for a phone, and on a tablet that shows: two dish cards
/// stretched to half a 10-inch screen each, checkout fields running the full
/// width, paragraphs eighty characters wide. Neither problem is about pixel
/// density — both are about a layout that only ever had one column in mind.
///
/// Two rules cover almost all of it:
///   * grids gain columns instead of stretching their cards;
///   * everything that reads like a form or a document stops growing at a
///     comfortable measure and centres, rather than filling the glass.
abstract final class Responsive {
  /// Where a layout stops being a phone. Matches the usual Material
  /// breakpoint, and also the point where two cards start looking silly.
  static const double _medium = 600;
  static const double _expanded = 1000;

  static double _width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => _width(context) < _medium;

  /// Columns for a grid of product cards. The card keeps roughly its phone
  /// size; the screen just fits more of them.
  static int gridColumns(BuildContext context, {int compact = 2}) {
    final width = _width(context);
    if (width >= _expanded) return compact + 2;
    if (width >= _medium) return compact + 1;
    return compact;
  }

  /// The widest a column of text, fields or list rows should get. Beyond
  /// this the eye loses the start of the next line.
  static const double readableWidth = 760;

  /// Horizontal breathing room, which a tablet can afford more of.
  static double pagePadding(BuildContext context) =>
      isCompact(context) ? 16 : 24;

  /// Widens [base]'s side padding until the content column is no broader
  /// than [readableWidth], which centres it without touching the widget
  /// tree — a scrolling list keeps its own padding property and nothing
  /// above it has to change.
  ///
  /// Returns [base] unchanged on a phone, so no screen can shift on the
  /// device most customers actually hold.
  static EdgeInsets pageInsets(
    BuildContext context,
    EdgeInsets base, {
    double? maxContentWidth,
  }) {
    final limit = maxContentWidth ?? readableWidth;
    final width = _width(context);
    final content = width - base.horizontal;
    if (content <= limit) return base;
    final gutter = (width - limit) / 2;
    return base.copyWith(left: gutter, right: gutter);
  }
}

/// Centres [child] and stops it growing past a readable measure.
///
/// Deliberately a no-op on a phone: there it simply hands the child the full
/// width it already had, so wrapping a screen in this can never change how
/// that screen looks on the device most customers hold.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Responsive.readableWidth,
        ),
        child: child,
      ),
    );
  }
}
