import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/modules/home/widgets/dish_photo_gallery.dart';

/// The photo area sits under two decorative overlays — a shade gradient and
/// the page dots. A plain `DecoratedBox` over the pager swallows the pointer
/// outright, which is exactly what stopped the gallery from swiping at all,
/// so this pins the behaviour rather than the widget tree that produces it.
void main() {
  testWidgets('swipes between photos through its overlays', (tester) async {
    final controller = PageController();
    var index = 0;
    final dish = Dish(
      id: '1',
      name: 'Palow',
      description: '',
      price: 10,
      categoryId: 'c1',
    );
    const photos = ['a.png', 'b.png', 'c.png'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              height: 320,
              child: DishPhotoGallery(
                dish: dish,
                photos: photos,
                controller: controller,
                index: index,
                onPageChanged: (i) => setState(() => index = i),
                dotsBottomInset: 40,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(index, 1);
  });
}
