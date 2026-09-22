import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/cafe.dart';
import 'package:food_delivery/core/theme/app_icons.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:food_delivery/modules/home/widgets/cafe_selector.dart';

const _cafes = [
  Cafe(id: 'han', name: 'Han tagam', sortOrder: 0),
  Cafe(id: 'panda', name: 'Panda', sortOrder: 1),
];

Future<String?> pump(
  WidgetTester tester, {
  required List<Cafe> cafes,
  String? selected,
}) async {
  String? tapped;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CafeSelector(
          cafes: cafes,
          selectedId: selected,
          onSelect: (id) => tapped = id,
        ),
      ),
    ),
  );
  return tapped;
}

void main() {
  testWidgets('lists every cafe by name', (tester) async {
    await pump(tester, cafes: _cafes, selected: 'han');
    expect(find.text('Han tagam'), findsOneWidget);
    expect(find.text('Panda'), findsOneWidget);
  });

  testWidgets('a single cafe is not a choice, so nothing is shown', (
    tester,
  ) async {
    await pump(tester, cafes: [_cafes.first], selected: 'han');
    expect(find.text('Han tagam'), findsNothing);
  });

  testWidgets('tapping a card reports that cafe', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CafeSelector(
            cafes: _cafes,
            selectedId: 'han',
            onSelect: (id) => tapped = id,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Panda'));
    await tester.pump();
    expect(tapped, 'panda');
  });

  testWidgets('two cafes share the full width instead of scrolling', (
    tester,
  ) async {
    await pump(tester, cafes: _cafes, selected: 'han');

    // No pager to scroll: with a pair of cafes the choice fills the row, so
    // neither card is half off the edge and no empty gutter is left over.
    expect(find.byType(ListView), findsNothing);
    final first = tester.getSize(find.text('Han tagam'));
    final second = tester.getSize(find.text('Panda'));
    expect(first.width, greaterThan(0));
    expect(second.width, greaterThan(0));
  });

  testWidgets('only the selected card is marked', (tester) async {
    await pump(tester, cafes: _cafes, selected: 'han');

    // The chosen cafe gets the brand check badge; the others get nothing.
    // Every card also draws a placeholder glyph when it has no photo, so the
    // badge is matched by its own icon rather than by counting icons.
    final badges = tester
        .widgetList<HugeIcon>(find.byType(HugeIcon))
        .where((icon) => icon.icon == AppIcons.check)
        .length;
    expect(badges, 1);

    // And the unselected ones are dimmed rather than bordered, which is what
    // keeps the photos — not a loud outline — doing the work.
    final dimmers = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color.a > 0 && box.color.a < 1)
        .length;
    expect(dimmers, 1);
  });
}
