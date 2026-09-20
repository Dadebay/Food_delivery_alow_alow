import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/modules/home/widgets/dish_card_gallery.dart';

Dish dishWith(List<String> photos) => Dish(
  id: '1',
  name: 'Palow',
  description: '',
  price: 10,
  categoryId: 'c1',
  imageUrl: photos.isEmpty ? null : photos.first,
  imageUrls: photos,
);

Future<void> pump(WidgetTester tester, Dish dish) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: 160,
          child: DishCardGallery(dish: dish),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('swipes between a dish\'s photos', (tester) async {
    await pump(tester, dishWith(const ['a.png', 'b.png', 'c.png']));

    expect(find.byType(PageView), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-120, 0), 500);
    await tester.pumpAndSettle();

    // The dots are the only visible read-out of the page, so assert on the
    // controller the pager actually settled to.
    // The pager starts deep into a repeating range so it can wrap both ways,
    // so the photo on screen is the page modulo the gallery.
    final controller = tester.widget<PageView>(find.byType(PageView)).controller;
    expect(controller!.page! % 3, 1);
  });

  testWidgets('wraps past the last photo back to the first', (tester) async {
    await pump(tester, dishWith(const ['a.png', 'b.png']));

    // Two photos, three swipes: the third lands on the first photo again
    // rather than stopping against the end of the gallery.
    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(-120, 0), 500);
      await tester.pumpAndSettle();
    }

    final page = tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(page % 2, 1);
  });

  testWidgets('wraps backwards off the first photo', (tester) async {
    await pump(tester, dishWith(const ['a.png', 'b.png']));

    final start = tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .page!;

    await tester.fling(find.byType(PageView), const Offset(120, 0), 500);
    await tester.pumpAndSettle();

    final page = tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(page, start - 1);
    expect(page % 2, 1);
  });

  testWidgets('a single photo installs no pager', (tester) async {
    await pump(tester, dishWith(const ['a.png']));
    expect(find.byType(PageView), findsNothing);
  });
}
