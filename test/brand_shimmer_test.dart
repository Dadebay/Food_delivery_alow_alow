import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/theme/app_text_styles.dart';
import 'package:food_delivery/core/widgets/brand_shimmer.dart';

void main() {
  testWidgets('shows the wordmark in the display face', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 180, height: 160, child: BrandShimmerBox())),
      ),
    );

    final text = tester.widget<Text>(find.text(BrandShimmerText.wordmark));
    expect(text.style?.fontFamily, AppText.wordmarkFamily);
  });
}
