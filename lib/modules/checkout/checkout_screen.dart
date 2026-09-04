import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/data/order_repository.dart' show OrderPlacementException;
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/order_quote.dart';
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

  // Guards against re-quoting `POST /delivery/quote` on every rebuild —
  // only fires again once the address or the cart subtotal actually
  // changes. This call only exists to learn the etrap for the address; the
  // fee it returns is a preview, not what checkout charges.
  DeliveryAddress? _quotedAddress;
  double? _quotedAddressSubtotal;

  // Guards the authoritative `POST /orders/quote` call the same way.
  double? _quotedSubtotal;
  int? _quotedEtrapId;

  /// The backend's own pricing for the current cart — item prices, promo
  /// discount and delivery fee, all recomputed server-side. `null` until
  /// the first response arrives; every number this screen shows comes from
  /// here, never from local arithmetic.
  OrderQuote? _quote;

  bool _promoApplied = false;
  bool _promoLoading = false;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    // Also clears a stale rejection message the moment the customer starts
    // typing a different code, rather than leaving it stuck until the next
    // apply attempt.
    _promoCode.addListener(() {
      if (_promoError != null) {
        setState(() => _promoError = null);
      } else {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      if (cart.isNotEmpty) {
        AnalyticsService.instance.checkoutStarted(cart.items, cart.subtotal);
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

  /// Re-quotes `POST /delivery/quote` for the address whenever it or the
  /// subtotal changed — this is only how `AddressProvider.deliveryEtrapId`
  /// gets resolved from raw coordinates; `_loadQuote` below is what
  /// actually prices the order.
  void _maybeRefreshAddressQuote(DeliveryAddress? address, double subtotal) {
    if (address == null) return;
    if (identical(_quotedAddress, address) &&
        _quotedAddressSubtotal == subtotal) {
      return;
    }
    _quotedAddress = address;
    _quotedAddressSubtotal = subtotal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AddressProvider>().refreshQuote(subtotal);
    });
  }

  /// Re-quotes `POST /orders/quote` whenever the cart or the resolved
  /// delivery etrap changed — this is the only place the delivery fee, the
  /// promo discount and the grand total come from.
  void _maybeRefreshOrderQuote(double subtotal, int? etrapId) {
    if (_quotedSubtotal == subtotal && _quotedEtrapId == etrapId) return;
    _quotedSubtotal = subtotal;
    _quotedEtrapId = etrapId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadQuote();
    });
  }

  /// Loads `/orders/quote` for the current cart, address and (if applied)
  /// promo code. Pass [promoCode] only when the customer just tapped
  /// "apply" — a background refresh (triggered by [_maybeRefreshOrderQuote])
  /// reuses whatever code is already applied and never surfaces its own
  /// errors loudly, so a stale network hiccup doesn't wipe out an
  /// already-applied promo's last-known-good numbers.
  Future<void> _loadQuote({String? promoCode}) async {
    final applyingPromo = promoCode != null;
    final cart = context.read<CartProvider>();
    final addresses = context.read<AddressProvider>();
    final orders = context.read<OrderProvider>();

    if (applyingPromo) {
      FocusScope.of(context).unfocus();
      setState(() {
        _promoLoading = true;
        _promoError = null;
      });
    }
    try {
      final quote = await orders.quote(
        items: cart.items.toList(),
        subtotal: cart.subtotal,
        deliveryEtrapId: addresses.deliveryEtrapId,
        promoCode:
            promoCode ?? (_promoApplied ? _promoCode.text.trim() : null),
      );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        if (applyingPromo) _promoApplied = true;
      });
      // Confirms the code actually did something — the field itself already
      // shows the discount once applied, but a snackbar is what makes the
      // saving register in the moment, right as it lands.
      if (applyingPromo && quote.discount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.sr.promoDiscountApplied(Fmt.money(quote.discount)))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (applyingPromo) {
        setState(() => _promoError = _orderErrorMessage(error, context.sr));
      }
    } finally {
      if (applyingPromo && mounted) setState(() => _promoLoading = false);
    }
  }

  void _applyPromo() {
    final code = _promoCode.text.trim();
    if (code.isEmpty) return;
    _loadQuote(promoCode: code);
  }

  void _removePromo() {
    _promoCode.clear();
    setState(() {
      _promoApplied = false;
      _promoError = null;
    });
    _loadQuote();
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
    final addresses = context.read<AddressProvider>();
    final s = context.sr;

    setState(() => _placing = true);
    try {
      final order = await orders.placeOrder(
        items: cart.items.toList(),
        address: address,
        subtotal: cart.subtotal,
        discount: _quote?.discount ?? 0,
        promoCode: _promoCode.text.trim().isEmpty ? null : _promoCode.text.trim(),
        deliveryEtrapId: addresses.deliveryEtrapId,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_orderErrorMessage(error, s))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// The backend rejects a bad/expired/exhausted promo code with a specific
  /// English message (see `orders.service.ts`) — matched here so the
  /// customer sees it in their own language instead of raw server text.
  String _orderErrorMessage(Object error, AppStrings s) {
    if (error is! OrderPlacementException) return s.orderPlaceFailedMessage;
    return switch (error.serverMessage) {
      'Promo code is unavailable' => s.promoCodeUnavailable,
      'Promo code usage limit reached' => s.promoCodeLimitReached,
      'Promo code was just exhausted' => s.promoCodeUnavailable,
      _ => s.orderPlaceFailedMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final address = addressProvider.address;
    _maybeRefreshAddressQuote(address, cart.subtotal);
    _maybeRefreshOrderQuote(cart.subtotal, addressProvider.deliveryEtrapId);
    final quote = _quote;

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
          _PromoField(
            controller: _promoCode,
            strings: s,
            applied: _promoApplied,
            loading: _promoLoading,
            discount: quote?.discount ?? 0,
            error: _promoError,
            onApply: _applyPromo,
            onRemove: _removePromo,
          ),
          const SizedBox(height: 12),
          _PaymentCard(strings: s),
          const SizedBox(height: 12),
          _TotalsCard(cart: cart, quote: quote, strings: s),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        cart: cart,
        quote: quote,
        strings: s,
        busy: _placing,
        onPlaceOrder: (cart.isEmpty || quote == null) ? null : () => _handlePlaceOrder(address),
      ),
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
                          item.displayName,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('${item.quantity} × ${Fmt.money(item.unitPrice)}', style: AppText.bodyMuted),
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
  const _PromoField({
    required this.controller,
    required this.strings,
    required this.applied,
    required this.loading,
    required this.discount,
    required this.error,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final AppStrings strings;

  /// Whether the backend has confirmed this code and [discount] is real.
  final bool applied;

  /// True while `_applyPromo` is waiting on the quote request.
  final bool loading;

  /// The live discount amount for the applied code — 0 until [applied].
  final double discount;

  /// The backend's rejection reason, translated — shown under the field
  /// until the next edit or a successful apply.
  final String? error;

  final VoidCallback onApply;
  final VoidCallback onRemove;

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

  void _remove() {
    widget.onRemove();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: widget.applied
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
    return Column(
      key: const ValueKey('editing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SectionIcon(icon: AppIcons.discount, color: AppColors.gold, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: !widget.loading,
                textCapitalization: TextCapitalization.characters,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                onSubmitted: (_) => widget.onApply(),
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
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => TextButton(
                  onPressed: value.text.trim().isEmpty ? null : widget.onApply,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), foregroundColor: AppColors.green, disabledForegroundColor: AppColors.textMuted),
                  child: Text(s.promoApply, style: AppText.chip.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(widget.error!, style: AppText.bodyMuted.copyWith(color: AppColors.red, fontSize: 12)),
          ),
        ],
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
        Text(
          '-${Fmt.money(widget.discount)}',
          style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.green),
        ),
        const SizedBox(width: 8),
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
  const _TotalsCard({required this.cart, required this.quote, required this.strings});

  final CartProvider cart;

  /// The backend's own pricing for this cart — `null` until the first
  /// `/orders/quote` response arrives. The delivery fee, discount and total
  /// rows show a loading state rather than a guessed number until then.
  final OrderQuote? quote;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _Row(label: strings.dishesTotal, value: Fmt.money(quote?.subtotal ?? cart.subtotal)),
          const SizedBox(height: 10),
          _Row(
            label: strings.deliveryFeeLabel,
            value: quote != null ? Fmt.money(quote!.deliveryFee) : '…',
          ),
          if (quote != null && quote!.discount > 0) ...[
            const SizedBox(height: 10),
            _Row(label: strings.discountLabel, value: '-${Fmt.money(quote!.discount)}', valueColor: AppColors.orange),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
            child: quote != null
                ? _Row(label: strings.grandTotal, value: Fmt.money(quote!.total), bold: true)
                : Row(
                    children: [
                      Expanded(child: Text(strings.grandTotal, style: AppText.h2.copyWith(fontSize: 18))),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                      ),
                    ],
                  ),
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
  const _BottomBar({required this.cart, required this.quote, required this.strings, required this.busy, required this.onPlaceOrder});

  final CartProvider cart;
  final OrderQuote? quote;
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
                  if (quote != null)
                    Text(Fmt.money(quote!.total), style: AppText.h2.copyWith(fontSize: 19))
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                label: strings.placeOrder,
                leading: Image.asset('assets/panda_order.png', width: 50, height: 50, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                busy: busy,
                onPressed: onPlaceOrder,
              ),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 370),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 194,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.green, AppColors.greenLight]),
                        ),
                        child: SizedBox.expand(),
                      ),
                      Positioned(
                        right: -28,
                        top: -44,
                        child: Container(
                          width: 154,
                          height: 154,
                          decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/images/create_order.png', height: 165, fit: BoxFit.contain),
                      ),
                      Positioned(
                        bottom: 14,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.check_rounded, color: AppColors.green, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.orderPlacedTitle, style: AppText.h2.copyWith(fontSize: 23), textAlign: TextAlign.center),
                      const SizedBox(height: 9),
                      Text(s.orderPlacedHint, style: AppText.bodyMuted, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(minHeight: 4, color: AppColors.green, backgroundColor: AppColors.cream),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
