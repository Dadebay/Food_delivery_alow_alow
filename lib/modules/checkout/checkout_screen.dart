import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/delivery_address.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_provider.dart';
import '../orders/order_provider.dart';
import '../orders/order_track_screen.dart';
import '../shell/tab_switcher.dart';
import 'address_picker_screen.dart';
import 'address_provider.dart';

/// Checkout — address, order lines, "Сдача с какой суммы", cash/card choice
/// (card is greyed out — phase 2, proposal slide 14), price breakdown, place
/// order. A single scroll of clearly separated, icon-led cards so the
/// customer can scan status (where / what / how much) at a glance, closed by
/// a sticky summary bar that keeps the total in view while they scroll.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _promoCode = TextEditingController();
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _promoCode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      if (cart.isNotEmpty) {
        AnalyticsService.instance.checkoutStarted(cart.items, cart.total);
      }
      // Nothing else loads the customer's saved/active address before this
      // screen watches it — without this, "place order" stays disabled
      // even when they already have an address on file.
      final addresses = context.read<AddressProvider>();
      if (addresses.address == null) addresses.load();
    });
  }

  @override
  void dispose() {
    _promoCode.dispose();
    super.dispose();
  }

  Future<void> _pickAddress(DeliveryAddress? current) async {
    final address = await Navigator.of(context).push<DeliveryAddress>(MaterialPageRoute(builder: (_) => AddressPickerScreen(initial: current)));
    if (address != null && mounted) {
      // Anything picked on the map is a real address the customer wants
      // to use again, not a one-off — save it rather than only holding it
      // in memory for this order.
      await context.read<AddressProvider>().addNew(address);
    }
  }

  void _handlePlaceOrder(DeliveryAddress? address) {
    if (!context.read<AuthProvider>().isSignedIn) {
      _SignInRequiredDialog.show(context);
      return;
    }
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.sr.selectAddressFirst)));
      return;
    }
    _placeOrder(address);
  }

  Future<void> _placeOrder(DeliveryAddress address) async {
    final cart = context.read<CartProvider>();
    final orders = context.read<OrderProvider>();

    setState(() => _placing = true);
    try {
      final order = await orders.placeOrder(
        items: cart.items.toList(),
        address: address,
        subtotal: cart.subtotal,
        discount: cart.discount,
        promoCode: _promoCode.text.trim().isEmpty ? null : _promoCode.text.trim(),
      );
      await AnalyticsService.instance.orderPlaced(order);
      cart.clear();
      if (!mounted) return;

      await showDialog<void>(context: context, barrierColor: Colors.black.withValues(alpha: 0.55), builder: (_) => const _OrderAcceptedDialog());
      if (!mounted) return;

      context.read<TabSwitcher>().go(3);
      await Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: order.id)), (route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    final address = context.watch<AddressProvider>().address;

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(
        title: Text(s.checkoutTitle),

        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          _AddressCard(address: address, strings: s, onTap: () => _pickAddress(address)),
          const SizedBox(height: 12),
          _ItemsCard(cart: cart, strings: s),
          const SizedBox(height: 12),
          _PromoField(controller: _promoCode, strings: s),
          const SizedBox(height: 12),
          _PaymentCard(strings: s),
          const SizedBox(height: 12),
          _TotalsCard(cart: cart, strings: s),
        ],
      ),
      bottomNavigationBar: _BottomBar(cart: cart, strings: s, busy: _placing, onPlaceOrder: cart.isEmpty ? null : () => _handlePlaceOrder(address)),
    );
  }
}

/// Shared white, rounded, softly-shadowed surface every checkout section
/// sits on — the one visual unit the whole screen is built from.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Small tinted circle carrying a section's glyph — the same soft-badge
/// language repeated once per card so the eye can jump straight to the part
/// of checkout it's looking for (where / what / how much).
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color, this.size = 34});

  final HugeIconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(
        child: HugeIcon(icon: icon, color: color, size: size * 0.5),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.strings, required this.onTap});

  final DeliveryAddress? address;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionIcon(icon: AppIcons.location, color: AppColors.green),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.deliveryAddressLabel, style: AppText.label),
                      const SizedBox(height: 6),
                      if (address == null)
                        Text(strings.pickOnMap, style: AppText.h2.copyWith(fontSize: 16))
                      else ...[
                        Text(
                          address!.fullLine(districtLabel: strings.districtLabel, houseLabel: strings.houseLabel),
                          style: AppText.h2.copyWith(fontSize: 16),
                        ),
                        if (address!.entrance != null || address!.floor != null || address!.apartment != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            address!.detailLine(entranceLabel: strings.entranceLabel, floorLabel: strings.floorLabel, apartmentLabel: strings.apartmentLabel),
                            style: AppText.bodyMuted,
                          ),
                        ],
                        if (address!.note != null) ...[const SizedBox(height: 6), Text(address!.note!, style: AppText.bodyMuted.copyWith(fontStyle: FontStyle.italic))],
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (address != null) Text(strings.changeAddress, style: AppText.chip.copyWith(color: AppColors.green, fontSize: 12)),
                    const SizedBox(height: 2),
                    const HugeIcon(icon: AppIcons.chevronRight, color: AppColors.textMuted, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.cart, required this.strings});

  final CartProvider cart;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(icon: AppIcons.package, color: AppColors.orange),
              const SizedBox(width: 12),
              Text(strings.itemsSummaryLabel, style: AppText.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(20)),
                child: Text(strings.dishesCount(cart.itemCount), style: AppText.chip.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in cart.items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: DishThumbnail(dish: item.dish, borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.dish.name,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('${item.quantity} × ${Fmt.money(item.dish.discountedPrice)}', style: AppText.bodyMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Fmt.money(item.lineTotal), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (item != cart.items.last) const Padding(padding: EdgeInsets.only(bottom: 12), child: Divider(height: 1)),
          ],
        ],
      ),
    );
  }
}

/// Collapsed by default — most orders have no promo code, so the field
/// starts as a single quiet prompt row rather than an always-open text
/// field competing for attention. Tapping it reveals the input; a code that
/// gets applied collapses back down into a compact success chip.
class _PromoField extends StatefulWidget {
  const _PromoField({required this.controller, required this.strings});

  final TextEditingController controller;
  final AppStrings strings;

  @override
  State<_PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends State<_PromoField> {
  bool _expanded = false;
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _apply() {
    if (widget.controller.text.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() => _expanded = false);
  }

  void _remove() {
    widget.controller.clear();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final applied = !_expanded && widget.controller.text.trim().isNotEmpty;

    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: applied
            ? _appliedRow(s)
            : _expanded
            ? _editingRow(s)
            : _idleRow(s),
      ),
    );
  }

  Widget _idleRow(AppStrings s) {
    return InkWell(
      key: const ValueKey('idle'),
      onTap: _expand,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          _SectionIcon(icon: AppIcons.discount, color: AppColors.gold, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.promoCodePrompt, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          ),
          const HugeIcon(icon: AppIcons.add, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }

  Widget _editingRow(AppStrings s) {
    return Row(
      key: const ValueKey('editing'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SectionIcon(icon: AppIcons.discount, color: AppColors.gold, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.characters,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            onSubmitted: (_) => _apply(),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: s.promoCodeHint,
              hintStyle: AppText.bodyMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty ? null : _apply,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), foregroundColor: AppColors.green, disabledForegroundColor: AppColors.textMuted),
            child: Text(s.promoApply, style: AppText.chip.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _appliedRow(AppStrings s) {
    return Row(
      key: const ValueKey('applied'),
      children: [
        _SectionIcon(icon: AppIcons.checkCircle, color: AppColors.green, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.controller.text.trim().toUpperCase(),
            style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.green),
          ),
        ),
        InkWell(
          onTap: _remove,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: HugeIcon(icon: AppIcons.cancel, color: AppColors.textMuted, size: 18),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.paymentMethodLabel, style: AppText.label),
          const SizedBox(height: 12),
          _PaymentOption(icon: AppIcons.money, label: strings.payCash, selected: true),
          const SizedBox(height: 10),
          _PaymentOption(icon: AppIcons.creditCard, label: strings.payCard, badge: strings.payCardPhase2, selected: false, enabled: false),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.icon, required this.label, required this.selected, this.badge, this.enabled = true});

  final HugeIconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.green.withValues(alpha: 0.08) : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.green : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            HugeIcon(icon: icon, color: selected ? AppColors.green : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: selected ? AppColors.textPrimary : AppColors.textSecondary),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(20)),
                child: Text(badge!, style: AppText.chip.copyWith(fontSize: 11, color: AppColors.textMuted)),
              )
            else if (selected)
              const HugeIcon(icon: AppIcons.checkCircle, color: AppColors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.cart, required this.strings});

  final CartProvider cart;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _Row(label: strings.dishesTotal, value: Fmt.money(cart.subtotal)),
          const SizedBox(height: 10),
          _Row(label: strings.deliveryFeeLabel, value: Fmt.money(cart.deliveryFee)),
          if (cart.discount > 0) ...[const SizedBox(height: 10), _Row(label: strings.discountLabel, value: '-${Fmt.money(cart.discount)}', valueColor: AppColors.orange)],
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
            child: _Row(label: strings.grandTotal, value: Fmt.money(cart.total), bold: true),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? AppText.h2.copyWith(fontSize: 18) : AppText.body;
    return Row(
      children: [
        Expanded(child: Text(label, style: bold ? style : AppText.bodyMuted)),
        Text(value, style: style.copyWith(color: valueColor)),
      ],
    );
  }
}

/// Sticky summary + CTA. Keeps the running item count and total in view the
/// whole time the customer scrolls the sections above, so the price never
/// feels like a surprise revealed only at the very bottom.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.cart, required this.strings, required this.busy, required this.onPlaceOrder});

  final CartProvider cart;
  final AppStrings strings;
  final bool busy;
  final VoidCallback? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(strings.dishesCount(cart.itemCount), style: AppText.bodyMuted),
                  const Spacer(),
                  Text(Fmt.money(cart.total), style: AppText.h2.copyWith(fontSize: 19)),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(label: strings.placeOrder, icon: AppIcons.checkCircle, busy: busy, onPressed: onPlaceOrder),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of silently failing when a signed-out customer taps place
/// order — the cart, address, and totals below all render fine without an
/// account, so this is the first point that actually needs one.
class _SignInRequiredDialog extends StatelessWidget {
  const _SignInRequiredDialog();

  static Future<void> show(BuildContext context) => showDialog<void>(context: context, builder: (_) => const _SignInRequiredDialog());

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: HugeIcon(icon: AppIcons.user, color: AppColors.green, size: 26),
            ),
            const SizedBox(height: 18),
            Text(s.loginTitle, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.signInPromptCheckout, style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(label: s.cancel, height: 48, onPressed: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: s.signIn,
                    height: 48,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Celebratory confirmation shown the moment an order goes through — closes
/// itself after a beat so it reads as a status flash rather than a dialog
/// the customer has to dismiss, but stays tappable for anyone who doesn't
/// want to wait.
class _OrderAcceptedDialog extends StatefulWidget {
  const _OrderAcceptedDialog();

  @override
  State<_OrderAcceptedDialog> createState() => _OrderAcceptedDialogState();
}

class _OrderAcceptedDialogState extends State<_OrderAcceptedDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bleeds to the dialog's own rounded corners instead of sitting
            // in the same inset as the text below — the illustration reads
            // as a panel of its own, not just another padded paragraph.
            Container(
              width: double.infinity,
              // padding: const EdgeInsets.symmetric(vertical: 28),
              color: AppColors.cream,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/images/create_order.png', height: 160, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.orderPlacedTitle, style: AppText.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(s.orderPlacedHint, style: AppText.bodyMuted, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
