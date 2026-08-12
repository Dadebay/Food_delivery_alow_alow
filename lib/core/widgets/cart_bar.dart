import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../modules/cart/cart_provider.dart';
import '../localization/locale_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// The floating "go to cart" bar that appears the moment the cart stops
/// being empty.
///
/// Lives here rather than inside the home screen because every screen the
/// customer can add a dish from needs it — otherwise adding from a category
/// gives no confirmation at all, and the dish they just added is one they
/// have to go hunting for.
class CartBar extends StatelessWidget {
  const CartBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    if (cart.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child:
            Material(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: AppIcons.cart,
                            color: AppColors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.cartBarLabel(cart.itemCount),
                              style: AppText.button.copyWith(
                                color: AppColors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Fmt.money(cart.total),
                            style: AppText.button.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                // Slides up the first time it appears — the customer's tap
                // on a card gets an answer at the bottom of the screen.
                .animate()
                .fadeIn(duration: 220.ms)
                .slideY(
                  begin: 0.6,
                  end: 0,
                  duration: 320.ms,
                  curve: Curves.easeOutCubic,
                ),
      ),
    );
  }
}
