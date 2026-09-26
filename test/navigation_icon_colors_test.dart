import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/theme/app_colors.dart';
import 'package:food_delivery/core/theme/app_icons.dart';
import 'package:food_delivery/modules/shell/animated_bottom_nav_bar.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  testWidgets('unselected category icon uses the muted grey stroke', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AnimatedBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              NavBarItemData(icon: AppIcons.home, label: 'Home'),
              NavBarItemData(icon: AppIcons.category, label: 'Category'),
            ],
          ),
        ),
      ),
    );

    final icons = tester.widgetList<HugeIcon>(find.byType(HugeIcon)).toList();
    expect(icons, hasLength(2));
    expect(icons[1].color, AppColors.textMuted);
  });

  test('unselected favorite asset uses the muted grey outline', () async {
    final svg = await rootBundle.loadString('assets/icons/favorite_empty.svg');

    expect(svg, contains('#B3A39D'));
  });
}
