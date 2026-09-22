import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/cafe.dart';
import 'package:food_delivery/core/theme/app_colors.dart';
import 'package:food_delivery/modules/home/widgets/cafe_selector.dart';

/// Golden files render in a placeholder font unless the real one is loaded,
/// which turns every cafe name into a row of boxes — useless for judging a
/// layout whose whole question is how the names sit in the cards.
Future<void> loadGilroy() async {
  final loader = FontLoader('Gilroy');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Gilroy-$weight.ttf');
    if (file.existsSync()) {
      loader.addFont(
        Future.value(file.readAsBytesSync().buffer.asByteData()),
      );
    }
  }
  await loader.load();
}

/// Renders the cafe strip at a phone width so the two- and three-cafe
/// layouts can be looked at before a third cafe exists in the catalogue.
Future<void> shoot(
  WidgetTester tester,
  List<Cafe> cafes,
  String file,
) async {
  tester.view.physicalSize = const Size(1170, 560);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await loadGilroy();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: AppColors.cream,
        child: Center(
          child: CafeSelector(
            cafes: cafes,
            selectedId: cafes.first.id,
            onSelect: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(CafeSelector),
    matchesGoldenFile('goldens/$file'),
  );
}

void main() {
  const two = [
    Cafe(id: 'han', name: 'Han tagam', imageUrl: 'assets/logo_no_text.png'),
    Cafe(id: 'panda', name: 'Panda', imageUrl: 'assets/panda_order.png'),
  ];
  const three = [
    ...two,
    Cafe(id: 'третий', name: 'Alow Pizza', imageUrl: 'assets/logo_icon.png'),
  ];

  testWidgets('two cafes', (t) => shoot(t, two, 'cafe_selector_2.png'));
  testWidgets('three cafes', (t) => shoot(t, three, 'cafe_selector_3.png'));
}
