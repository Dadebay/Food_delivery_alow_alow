import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../checkout/checkout_screen.dart';
import 'cart_provider.dart';
import 'widgets/cart_line.dart';

/// The cart tab — matches `cust_cart.png`'s order-line list, feeding straight
/// into checkout.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  /// Browsing and building a cart never require an account — this is the one
  /// place that does, since placing an order needs somewhere to send status
  /// updates back to. Signing in here interrupts nothing that came before it.
  Future<void> _goToCheckout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      final signedIn = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (signedIn != true) return;
    }
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s.cartTitle)),
      body: cart.isEmpty
          ? _Empty(title: s.cartEmpty, hint: s.cartEmptyHint)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return CartLine(
                  item: item,
                  onIncrement: () =>
                      cart.setQuantity(item.dish, item.quantity + 1),
                  onDecrement: () =>
                      cart.setQuantity(item.dish, item.quantity - 1),
                  onRemove: () => cart.remove(item.dish),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SummaryRow(
                      label: s.dishesTotal,
                      value: Fmt.money(cart.subtotal),
                    ),
                    if (cart.discount > 0) ...[
                      const SizedBox(height: 6),
                      _SummaryRow(
                        label: s.discountLabel,
                        value: '-${Fmt.money(cart.discount)}',
                        valueColor: AppColors.orange,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: s.deliveryFeeLabel,
                      value: Fmt.money(cart.deliveryFee),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: '${s.goToCheckout} · ${Fmt.money(cart.total)}',
                      onPressed: () => _goToCheckout(context),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.bodyMuted)),
        Text(
          value,
          style: AppText.body.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/empty_cart.png',
              width: double.infinity,
              height: 250,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 16),
            Text(title, style: AppText.h2),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center, style: AppText.bodyMuted),
          ],
        ),
      ),
    );
  }
}
