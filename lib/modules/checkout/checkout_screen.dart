import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/data/order_repository.dart' show OrderPlacementException;
import '../../core/constants/app_config.dart';
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
import '../../core/widgets/responsive.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../cart/cart_provider.dart';
import '../catalog/catalog_provider.dart';
import '../orders/order_provider.dart';
import '../orders/order_track_screen.dart';
import '../shell/tab_switcher.dart';
import '../../core/models/ordering_hours.dart';
import '../../core/utils/uuid_v4.dart';
import '../loyalty/loyalty_provider.dart';
import 'address_picker_screen.dart';
import 'address_provider.dart';
import 'ordering_hours_provider.dart';
import 'checkout_pricing.dart';

part 'checkout_sections.dart';
part 'checkout_pricing_widgets.dart';
part 'checkout_dialogs.dart';

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

  /// Free-text note for the whole order — sent as `customerNote`, shown in
  /// the admin and printed on the main and kitchen receipts.
  final TextEditingController _orderComment = TextEditingController();
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

  /// The `idempotencyKey` for the current basket.
  ///
  /// Generated once per basket and reused on every retry of that same
  /// basket, so a send that timed out can be repeated without risking a
  /// second order — the server recognises the key and returns the order it
  /// already has. Regenerated only when the customer deliberately changes
  /// what they are ordering, which is a different order and deserves a
  /// different key. Never regenerated while the outcome of a send is
  /// unknown: that is precisely the case this exists to protect.
  String? _idempotencyKey;

  /// The basket the current [_idempotencyKey] belongs to.
  String? _keyedBasket;

  /// A fingerprint of everything that makes this order what it is. Two
  /// sends with the same fingerprint are the same order being retried; a
  /// different one is a new order.
  String _basketSignature(CartProvider cart) {
    final items =
        cart.items
            .map((i) => '${i.dish.id}:${i.variant?.id ?? ''}:${i.quantity}')
            .toList()
          ..sort();
    final gifts = cart.gifts.map((g) => '${g.gift.id}:${g.quantity}').toList()
      ..sort();
    return '${items.join(',')}|${gifts.join(',')}';
  }

  String _keyFor(CartProvider cart) {
    final signature = _basketSignature(cart);
    if (_idempotencyKey == null || _keyedBasket != signature) {
      _idempotencyKey = uuidV4();
      _keyedBasket = signature;
    }
    return _idempotencyKey!;
  }

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
      // Whether orders are being taken at all. The provider re-reads this
      // by itself when the app returns from the background, so a phone left
      // on this screen overnight does not keep showing yesterday's "open".
      unawaited(context.read<OrderingHoursProvider>().refresh());
    });
  }

  @override
  void dispose() {
    _promoCode.dispose();
    _orderComment.dispose();
    super.dispose();
  }

  /// Re-quotes `POST /delivery/quote` for the address whenever it or the
  /// subtotal changed — this is only how `AddressProvider.deliveryEtrapId`
  /// gets resolved from raw coordinates; `_loadQuote` below is what
  /// actually prices the order.
  void _maybeRefreshAddressQuote(
    DeliveryAddress? address,
    double subtotal, {
    required bool hasQuote,
  }) {
    if (address == null) return;
    // [hasQuote] is what makes this safe against object identity. Every path
    // that changes the address clears the provider's quote, but not every
    // one hands back a fresh object: picking a point on the map within a few
    // metres of an address already on file reactivates that saved entry, so
    // `address` can be the very same instance that was quoted before while
    // the quote itself is gone. Keying on identity alone, checkout then sat
    // on the flat estimate and never asked the API again.
    //
    // No loop: a finished refresh always leaves a quote behind — the
    // server's, or the fallback — so this only fires while there is none.
    if (hasQuote &&
        identical(_quotedAddress, address) &&
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
  /// The gift selection the last quote was priced for — changing it changes
  /// the points, so it re-quotes exactly as a changed subtotal does.
  String? _quotedGifts;

  void _maybeRefreshOrderQuote(double subtotal, int? etrapId, String gifts) {
    if (_quotedSubtotal == subtotal &&
        _quotedEtrapId == etrapId &&
        _quotedGifts == gifts) {
      return;
    }
    _quotedSubtotal = subtotal;
    _quotedEtrapId = etrapId;
    _quotedGifts = gifts;
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
        promoCode: promoCode ?? (_promoApplied ? _promoCode.text.trim() : null),
        gifts: cart.gifts,
        // Distance pricing needs the point to price against. Harmless in
        // district mode, where the server ignores it in favour of the
        // etrap id above.
        point: addresses.address?.point,
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
          SnackBar(
            content: Text(
              context.sr.promoDiscountApplied(Fmt.money(quote.discount)),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (applyingPromo) {
        setState(() => _promoError = _orderErrorMessage(error, context.sr));
      } else if (_quote == null) {
        // A background refresh that fails used to leave `_quote` null, and
        // nothing ever asked again: the total spun a spinner forever and the
        // order button stayed dead. Price it here instead — the same
        // estimate the address card is already showing, and the server
        // prices the order properly at creation anyway.
        setState(
          () => _quote = OrderQuote.estimate(
            subtotal: cart.subtotal,
            deliveryFee: addresses.deliveryFee,
          ),
        );
        // Let the next build try the server again rather than trusting the
        // estimate for the rest of the session.
        _quotedSubtotal = null;
        _quotedEtrapId = null;
        _quotedGifts = null;
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
    final address = await Navigator.of(context).push<DeliveryAddress>(
      MaterialPageRoute(builder: (_) => AddressPickerScreen(initial: current)),
    );
    if (address != null && mounted) {
      // Anything picked on the map is a real address the customer wants
      // to use again, not a one-off — save it rather than only holding it
      // in memory for this order.
      try {
        await context.read<AddressProvider>().addNew(address);
      } catch (_) {
        // The address is already active for this order; only the address
        // book missed out. Saying so beats the old behaviour, where the
        // failure vanished and the screen just kept showing "pick on map".
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: context.sr.addressNotSaved,
          kind: AppSnackKind.error,
          icon: AppIcons.location,
        );
      }
    }
  }

  void _handlePlaceOrder(DeliveryAddress? address) {
    // `AppButton`'s disabled-while-busy state only takes effect on the next
    // frame — a fast double-tap can fire this twice before that rebuild
    // lands. This check runs synchronously in the tap handler itself, so
    // the second tap bails out immediately instead of racing the first
    // request's `cart.clear()` and sending an empty `items: []`.
    if (_placing) return;
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;
    if (!context.read<AuthProvider>().isSignedIn) {
      _SignInRequiredDialog.show(context);
      return;
    }
    if (address == null) {
      final s = context.sr;
      AppSnackBar.show(
        context,
        message: s.selectAddressFirst,
        icon: AppIcons.location,
        actionLabel: s.pickOnMap,
        onAction: () => _pickAddress(null),
      );
      return;
    }
    _placeOrder(address);
  }

  Future<void> _placeOrder(DeliveryAddress address) async {
    final cart = context.read<CartProvider>();
    final orders = context.read<OrderProvider>();
    final addresses = context.read<AddressProvider>();
    // Read before the await: the refreshes below run after it, and by then
    // this screen may already be gone.
    final loyalty = context.read<LoyaltyProvider>();
    final signedIn = context.read<AuthProvider>().isSignedIn;
    final s = context.sr;

    // The key is resolved before the request and deliberately not cleared
    // in `finally`: if this send times out, the next attempt must carry the
    // same key so the server can recognise the order it may already have.
    final idempotencyKey = _keyFor(cart);

    setState(() => _placing = true);
    try {
      final order = await orders.placeOrder(
        items: cart.items.toList(),
        address: address,
        subtotal: cart.subtotal,
        discount: _quote?.discount ?? 0,
        promoCode: _promoCode.text.trim().isEmpty
            ? null
            : _promoCode.text.trim(),
        deliveryEtrapId: addresses.deliveryEtrapId,
        orderComment: _orderComment.text.trim().isEmpty
            ? null
            : _orderComment.text.trim(),
        gifts: cart.gifts,
        idempotencyKey: idempotencyKey,
      );
      await AnalyticsService.instance.orderPlaced(order);
      cart.clear();
      _orderComment.clear();
      // This basket is spent; the next one is a different order.
      _idempotencyKey = null;
      _keyedBasket = null;
      // Placing an order spends gift points and reserves stock, so both the
      // balance and the catalogue have moved.
      unawaited(loyalty.refresh(signedIn: signedIn));
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => const _OrderAcceptedDialog(),
      );
      if (!mounted) return;

      context.read<TabSwitcher>().go(3);
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: order.id)),
        (route) => route.isFirst,
      );
    } catch (error, stackTrace) {
      // The `order_repository`'s own debug box already prints the raw
      // HTTP/server response for a non-2xx create-order call — this is the
      // one line that shows what checkout actually caught, in case the
      // failure happened above that (a thrown `StateError`, a cast, etc.).
      debugPrint('[PlaceOrder] failed: ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_orderErrorMessage(error, s))));
        _refreshCatalogAfterRejection(error);
        _refreshAfterConflict(error);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// A server rejection is authoritative about what is still orderable.
  ///
  /// A cafe or a product can be hidden while the customer is browsing, and
  /// the app must not argue with the server from cached screen state — so a
  /// rejected order sends the catalogue back for a fresh read. Only a real
  /// rejection counts: a lost connection says nothing about the menu, and
  /// re-reading it on every flaky network is a needless round trip.
  /// A 409 means the world moved between the quote and the send: points
  /// spent elsewhere, a gift sold out, the shop closing. Nothing local is
  /// treated as successful — the cart, including the gifts, is kept exactly
  /// as it was, and everything that could have changed is re-read so the
  /// customer confirms against the new state rather than the old one.
  void _refreshAfterConflict(Object error) {
    if (error is! OrderPlacementException) return;
    if (error.statusCode != 409) return;
    unawaited(
      context.read<LoyaltyProvider>().refresh(
        signedIn: context.read<AuthProvider>().isSignedIn,
      ),
    );
    unawaited(context.read<OrderingHoursProvider>().refresh());
    // Forget the quote fingerprint so the next build prices the cart again
    // instead of trusting the one the server just refused.
    _quotedSubtotal = null;
    _quotedEtrapId = null;
    _quotedGifts = null;
  }

  void _refreshCatalogAfterRejection(Object error) {
    if (error is! OrderPlacementException) return;
    unawaited(context.read<CatalogProvider>().refreshCatalog());
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

  /// Debug only — the last fee logged, so a rebuild that changes nothing
  /// does not repeat the line on every frame.
  String? _loggedFee;

  /// Debug only. Says which of the three sources the number on screen came
  /// from, which is the whole question when a fee looks wrong: the order
  /// quote's district price, the delivery endpoint's out-of-area rate, or
  /// this app's flat estimate.
  void _logDeliveryFee(double fee, int? etrapId, bool quoted) {
    final line =
        'showing $fee ${AppConfig.currency} '
        '(${quoted ? "order quote, etrapId=$etrapId" : "estimate — no district resolved"})';
    if (line == _loggedFee) return;
    _loggedFee = line;
    debugPrint('\x1B[30;106m DELIVERY \x1B[0m \x1B[96m$line\x1B[0m');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final address = addressProvider.address;
    _maybeRefreshAddressQuote(
      address,
      cart.subtotal,
      hasQuote: addressProvider.quote != null,
    );
    final hours = context.watch<OrderingHoursProvider>();
    final loyalty = context.watch<LoyaltyProvider>();
    _maybeRefreshOrderQuote(
      cart.subtotal,
      addressProvider.deliveryEtrapId,
      cart.gifts.map((g) => '${g.gift.id}:${g.quantity}').join(','),
    );
    final quote = _quote;

    // `/orders/quote` prices delivery from the `deliveryEtrapId` this screen
    // hands it, and answers 0 when it gets none — which happens both before
    // an address is picked and when the picked point fell outside every
    // configured etrap. That zero means "no district to charge for", not
    // free delivery, and taking it at face value had checkout promising a
    // free run nobody had quoted, with a total short by the fee.
    //
    // So the order quote's fee is only used once a district actually
    // resolved. Otherwise the fee comes from `/delivery/quote`, which
    // answers for a raw point: the backend's own out-of-area rate when it
    // replied, and this app's flat estimate when it did not.
    final etrapId = addressProvider.deliveryEtrapId;
    final pricing = CheckoutPricing.calculate(
      subtotal: cart.subtotal,
      quote: quote,
      addressDeliveryFee: addressProvider.deliveryFee,
      etrapId: etrapId,
    );
    // Anything but a district-specific price is shown as approximate: the
    // server prices the order again at creation time, and an out-of-area
    // rate can land differently.
    final deliveryIsQuoted = pricing.deliveryIsQuoted;
    final deliveryFee = pricing.deliveryFee;
    final total = pricing.total;
    _logDeliveryFee(deliveryFee, etrapId, deliveryIsQuoted);

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(
        title: Text(s.checkoutTitle),

        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.onBrand,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Three ways out of the keyboard, because a multiline field offers none
      // of its own on iOS: the accessory bar below, dragging the list, and a
      // tap on any empty part of the page.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: Responsive.pageInsets(
            context,
            const EdgeInsets.fromLTRB(16, 16, 16, 8),
          ),
          children: [
            _AddressCard(
              address: address,
              strings: s,
              onTap: () => _pickAddress(address),
            ),
            const SizedBox(height: 12),
            _ItemsCard(cart: cart, strings: s),
            const SizedBox(height: 12),
            _OrderCommentField(controller: _orderComment, strings: s),
            const SizedBox(height: 12),
            if (AppConfig.showPromoCode) ...[
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
            ],
            _PaymentCard(strings: s),
            const SizedBox(height: 12),
            // Only when this server does loyalty at all, and only when there
            // is something to say: no gifts chosen and no points moving means
            // an empty card, which reads as a feature that is broken rather
            // than one that is simply not in play for this order.
            if (!loyalty.unavailable &&
                (cart.hasGifts || (quote?.hasLoyalty ?? false))) ...[
              _LoyaltyCard(cart: cart, quote: quote, strings: s),
              const SizedBox(height: 12),
            ],
            _TotalsCard(
              cart: cart,
              quote: quote,
              strings: s,
              deliveryFee: deliveryFee,
              deliveryIsQuoted: deliveryIsQuoted,
              total: total,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        cart: cart,
        quote: quote,
        total: total,
        strings: s,
        busy: _placing,
        // The shop being shut is the one closed door with an explanation
        // attached, so the bar shows the window instead of a dead button.
        closedHours: hours.blocksOrdering ? hours.hours : null,
        onPlaceOrder:
            (cart.isEmpty ||
                hours.blocksOrdering ||
                (address != null && quote == null))
            ? null
            // With no address there is no quote to wait for, and a dead
            // button explains nothing. Let the tap through so the handler
            // can say what is missing and offer the map.
            : () => _handlePlaceOrder(address),
      ),
    );
  }
}
