part of 'checkout_screen.dart';

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
          _SectionIcon(
            icon: AppIcons.discount,
            color: AppColors.gold,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.promoCodePrompt,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const HugeIcon(
            icon: AppIcons.add,
            color: AppColors.textMuted,
            size: 18,
          ),
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
            _SectionIcon(
              icon: AppIcons.discount,
              color: AppColors.gold,
              size: 30,
            ),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onBrand,
                  ),
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => TextButton(
                  onPressed: value.text.trim().isEmpty ? null : widget.onApply,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    foregroundColor: AppColors.onBrand,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: Text(
                    s.promoApply,
                    style: AppText.chip.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              widget.error!,
              style: AppText.bodyMuted.copyWith(
                color: AppColors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _appliedRow(AppStrings s) {
    return Row(
      key: const ValueKey('applied'),
      children: [
        _SectionIcon(
          icon: AppIcons.checkCircle,
          color: AppColors.onBrand,
          size: 30,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.controller.text.trim().toUpperCase(),
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
        ),
        Text(
          '-${Fmt.money(widget.discount)}',
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _remove,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: HugeIcon(
              icon: AppIcons.cancel,
              color: AppColors.textMuted,
              size: 18,
            ),
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
          _PaymentOption(
            icon: AppIcons.money,
            label: strings.payCash,
            selected: true,
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            icon: AppIcons.creditCard,
            label: strings.payCard,
            badge: strings.payCardPhase2,
            selected: false,
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    this.badge,
    this.enabled = true,
  });

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
          color: selected
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected ? AppColors.onBrand : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: AppText.chip.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else if (selected)
              const HugeIcon(
                icon: AppIcons.checkCircle,
                color: AppColors.onBrand,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.cart,
    required this.quote,
    required this.strings,
    required this.deliveryFee,
    required this.deliveryIsQuoted,
    required this.total,
  });

  final CartProvider cart;

  /// The fee to show, already resolved by the screen: the backend's number
  /// when it priced this address, otherwise the app's estimate. Keeping that
  /// choice in one place is what stops this row and the bar at the bottom
  /// disagreeing about what delivery costs.
  final double deliveryFee;

  /// False while [deliveryFee] is the estimate — the heading says so, so
  /// nobody reads a guess as a settled price.
  final bool deliveryIsQuoted;

  final double total;

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
          _Row(
            label: strings.dishesTotal,
            value: Fmt.money(quote?.subtotal ?? cart.subtotal),
          ),
          const SizedBox(height: 10),
          _Row(
            // Tahmin oldugunda basligin kendisi bunu soyluyor — kullanici
            // kesin bir rakam sandigi seyle karsilasmasin.
            label: deliveryIsQuoted
                ? strings.deliveryFeeLabel
                : strings.deliveryFeeEstimated,
            value: Fmt.money(deliveryFee),
          ),
          if (quote != null && quote!.discount > 0) ...[
            const SizedBox(height: 10),
            _Row(
              label: strings.discountLabel,
              value: '-${Fmt.money(quote!.discount)}',
              valueColor: AppColors.orange,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            // Toplam da bekletilmiyor: sunucu cevabi yokken sepet toplami ile
            // yedek teslimat ucretinden hesaplaniyor. Onceden burada sonsuza
            // kadar donen bir gosterge vardi.
            child: _Row(
              label: strings.grandTotal,
              value: Fmt.money(total),
              bold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

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
  const _BottomBar({
    required this.cart,
    required this.quote,
    required this.total,
    required this.strings,
    required this.busy,
    required this.onPlaceOrder,
    this.closedHours,
  });

  final CartProvider cart;
  final OrderQuote? quote;

  /// Set only while the server says it is not taking orders. The cart stays
  /// exactly as it is — nothing is cleared, the customer simply cannot send
  /// it yet.
  final OrderingHours? closedHours;

  /// The same number the totals card shows — see [_TotalsCard.deliveryFee].
  final double total;
  final AppStrings strings;
  final bool busy;
  final VoidCallback? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (closedHours != null) ...[
                _ClosedNotice(hours: closedHours!, strings: strings),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Text(
                    strings.dishesCount(cart.itemCount),
                    style: AppText.bodyMuted,
                  ),
                  const Spacer(),
                  if (quote != null)
                    Text(
                      Fmt.money(total),
                      style: AppText.h2.copyWith(fontSize: 19),
                    )
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onBrand,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                label: strings.placeOrder,
                leading: Image.asset(
                  'assets/panda_order.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
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

/// The gifts riding along with this order, and what the points do.
///
/// Every number here comes from the quote. The app does not add up gift
/// costs or work out what the order will earn — the server prices both, and
/// a second opinion computed on the phone is exactly the disagreement a
/// customer would notice at the worst moment.
class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({
    required this.cart,
    required this.quote,
    required this.strings,
  });

  final CartProvider cart;
  final OrderQuote? quote;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // The server's copy once it has answered; the local selection until
    // then, so the card is not blank while the quote is in flight.
    final gifts = quote?.gifts ?? const [];
    final balance = quote?.pointsBalance;
    final spent = quote?.loyaltyPointsSpent;
    final earned = quote?.loyaltyPointsEarned;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.giftsInCart, style: AppText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          if (gifts.isNotEmpty)
            for (final gift in gifts) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${gift.name} ×${gift.quantity}',
                      style: AppText.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    strings.pointsValue(gift.totalPoints),
                    style: AppText.body.copyWith(color: AppColors.goldInk),
                  ),
                  IconButton(
                    tooltip: strings.removeGift,
                    icon: const HugeIcon(
                      icon: AppIcons.delete,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: () =>
                        context.read<CartProvider>().removeGift(gift.giftId),
                  ),
                ],
              ),
            ]
          else
            for (final line in cart.gifts) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.gift.name} ×${line.quantity}',
                      style: AppText.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    strings.pointsValue(line.totalPoints),
                    style: AppText.body.copyWith(color: AppColors.goldInk),
                  ),
                  IconButton(
                    tooltip: strings.removeGift,
                    icon: const HugeIcon(
                      icon: AppIcons.delete,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: () =>
                        context.read<CartProvider>().removeGift(line.gift.id),
                  ),
                ],
              ),
            ],
          if (balance != null || spent != null || earned != null) ...[
            const Divider(height: 20),
            if (balance != null)
              _Row(
                label: strings.pointsBalanceLabel,
                value: strings.pointsValue(balance),
              ),
            if (spent != null && spent > 0) ...[
              const SizedBox(height: 6),
              _Row(
                label: strings.pointsSpentOnGifts,
                value: '-${strings.pointsValue(spent)}',
                valueColor: AppColors.orange,
              ),
            ],
            if (earned != null && earned > 0) ...[
              const SizedBox(height: 6),
              // Deliberately worded as something that has not happened yet:
              // these land only once the order reaches DELIVERED, and they
              // cannot pay for a gift in this same order.
              _Row(
                label: strings.pointsEarnedAfterDelivery,
                value: '+${strings.pointsValue(earned)}',
                valueColor: AppColors.success,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "We are closed" with the window to come back in.
///
/// The times are shown as the server wrote them, with its timezone, rather
/// than converted to the phone's: the restaurant's hours are a fact about
/// the restaurant, and a customer travelling with their phone on another
/// timezone should still read the shop's own opening time.
class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.hours, required this.strings});

  final OrderingHours hours;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.goldSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.orderingClosedTitle,
          style: AppText.h2.copyWith(fontSize: 14, color: AppColors.goldInk),
        ),
        const SizedBox(height: 4),
        Text(
          hours.hasWindow
              ? strings.orderingClosedMessage(hours.opensAt!, hours.closesAt!)
              : strings.orderingClosedNow,
          style: AppText.bodyMuted.copyWith(fontSize: 12),
        ),
      ],
    ),
  );
}
