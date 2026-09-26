import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/modules/cart/cart_provider.dart';
import 'package:food_delivery/modules/home/widgets/dish_card.dart';
import 'package:provider/provider.dart';

/// The whole card, not just its gallery: the photo sits under the card's own
/// overlays, and a decorative one that accepts the pointer — a `DecoratedBox`
/// laid over the pager, for instance — stops the swipe dead while still
/// looking perfectly fine on screen.
void main() {
  testWidgets('photos swipe inside a full dish card', (tester) async {
    final dish = Dish(
      id: '1',
      name: 'Palow',
      description: '',
      price: 10,
      categoryId: 'c1',
      discountPercent: 15,
      imageUrl: 'a.png',
      imageUrls: const ['a.png', 'b.png', 'c.png'],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 260,
                child: DishCard(
                  dish: dish,
                  onTap: () {},
                  onToggleFavorite: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.byType(PageView), const Offset(-120, 0), 500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The gallery loops, so it starts deep into a repeating range: the photo
    // on screen is the page modulo the gallery.
    final page = tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(page % 3, 1);
  });
}
