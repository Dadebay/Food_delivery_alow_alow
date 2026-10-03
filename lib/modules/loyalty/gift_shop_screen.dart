import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/loyalty_gift.dart';
import '../../core/services/catalog_image_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/brand_shimmer.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import 'loyalty_provider.dart';

/// The gift shop — everything that can be had for points.
///
/// Open to guests: browsing needs no account, only picking one does. A gift
/// is never bought on its own either; it rides along with an order that has
/// food in it, which is why the add button is disabled on an empty cart
/// rather than starting a checkout of its own.
class GiftShopScreen extends StatefulWidget {
  const GiftShopScreen({super.key});

  @override
  State<GiftShopScreen> createState() => _GiftShopScreenState();
}

class _GiftShopScreenState extends State<GiftShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final loyalty = context.read<LoyaltyProvider>();
      loyalty.loadGifts();
      // The balance is what decides whether a gift can be afforded at all,
      // so this screen asks for it rather than relying on whatever the
      // startup refresh happened to leave behind. The provider ignores a
      // second call while one is already in flight.
      if (context.read<AuthProvider>().isSignedIn) loyalty.loadAccount();
    });
  }

  void _add(LoyaltyGift gift) {
    final s = context.sr;
    final cart = context.read<CartProvider>();
    final loyalty = context.read<LoyaltyProvider>();
    final balance = loyalty.balance;
    final signedIn = context.read<AuthProvider>().isSignedIn;

    // Three refusals, three different reasons — a single "cannot add" would
    // leave the customer guessing which one they hit.
    if (!signedIn) {
      _logGiftAttempt(gift, cart, loyalty, verdict: 'REFUSED — not signed in');
      AppSnackBar.show(context, message: s.giftSignInNeeded);
      return;
    }
    final block = cart.giftBlock(gift, balance: balance);
    if (!block.allowed) {
      _logGiftAttempt(gift, cart, loyalty, block: block, verdict: 'REFUSED');
      AppSnackBar.show(context, message: _GiftCard.reasonText(block, s) ?? s.giftLimitReached);
      return;
    }
    if (!cart.addGift(gift, balance: balance)) {
      // The cart refused something the gate allowed: the two disagree, which
      // is a bug rather than a customer-facing state. Logged loudly for that
      // reason.
      _logGiftAttempt(gift, cart, loyalty, verdict: 'REFUSED by cart after the gate allowed it');
      AppSnackBar.show(context, message: s.giftLimitReached);
      return;
    }
    _logGiftAttempt(gift, cart, loyalty, verdict: 'ADDED');
    AppSnackBar.show(context, message: s.giftAdded, kind: AppSnackKind.success);
  }

  /// What the points looked like at the moment the customer tapped "add".
  ///
  /// The balance comes from the server, the gift's price comes from the
  /// catalogue and the running total comes from the cart — three sources that
  /// have to agree for the order to go through, and the only place they meet
  /// is this tap. Printing them together is what turns "it would not let me
  /// add it" into something answerable without a debugger.
  ///
  /// Debug builds only; nothing here reaches a release.
  static void _logGiftAttempt(
    LoyaltyGift gift,
    CartProvider cart,
    LoyaltyProvider loyalty, {
    GiftBlock? block,
    required String verdict,
  }) {
    if (!kDebugMode) return;
    final balance = loyalty.balance;

    const badge = '\x1B[30;102m GIFT \x1B[0m';
    const green = '\x1B[92m';
    const red = '\x1B[91m';
    const yellow = '\x1B[93m';
    const dim = '\x1B[90m';
    const reset = '\x1B[0m';

    final allowed = verdict == 'ADDED';
    final accent = allowed ? green : red;

    // The cart is read *after* a successful add, so `giftPoints` already
    // includes this gift. Reported both ways so neither number has to be
    // worked out by hand from the other.
    final committed = allowed ? cart.giftPoints - gift.pointsCost : cart.giftPoints;
    final wanted = committed + gift.pointsCost;

    void line(String label, Object? value) =>
        debugPrint('$badge $dim${label.padRight(16)}$reset $value');

    debugPrint('$badge $accent── $verdict ${'─' * 20}$reset');
    line('gift', '${gift.name} $dim(${gift.id})$reset');
    line('price', '$yellow${gift.pointsCost}$reset pts');
    line(
      'stock',
      gift.isUnlimited ? 'unlimited' : (gift.isSoldOut ? '${red}sold out$reset' : '${gift.stock}'),
    );
    // A missing balance is a real state and not zero — an unknown balance
    // lets the attempt through on purpose. But "not loaded" on its own says
    // nothing about why, and the why is the whole question when the number
    // never appears: still in flight, refused by the server, or never asked
    // for because this server has no loyalty at all.
    line(
      'balance',
      balance != null
          ? '$green$balance$reset pts'
          : loyalty.unavailable
              ? '${red}no loyalty on this server$reset'
              : loyalty.loadingAccount
                  ? '${yellow}still loading…$reset'
                  : loyalty.accountError != null
                      ? '${red}FAILED$reset $dim${loyalty.accountError}$reset'
                      : '${yellow}never requested$reset $dim(signed out, or loadAccount was not called)$reset',
    );
    line('already in cart', '$committed pts across ${cart.gifts.length} gift(s)');
    line('this one brings', '$committed + ${gift.pointsCost} = $accent$wanted$reset pts');
    if (balance != null) {
      final left = balance - wanted;
      line(
        'after this',
        left >= 0 ? '$green$left$reset pts left' : '$red${-left} pts short$reset',
      );
    }
    if (block != null && !block.allowed) {
      final short = block.reason == GiftBlockReason.notEnoughPoints
          ? ' ($red${block.shortfall}$reset pts short)'
          : '';
      line('refused by', '$red${block.reason.name}$reset$short');
    }
    line('cart', '${cart.items.length} dish line(s), subtotal ${cart.subtotal}');
    line('gift lines', cart.gifts.isEmpty
        ? '$dim—$reset'
        : cart.gifts.map((g) => '${g.gift.name}×${g.quantity}=${g.totalPoints}').join(', '));
    debugPrint('$badge $accent${'─' * 34}$reset');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final loyalty = context.watch<LoyaltyProvider>();
    final balance = loyalty.balance;

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(
        title: Text(s.giftShop),
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.onBrand),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // The balance is the number every price on this screen is judged
          // against, so a missing one is worth a tappable retry rather than
          // an empty corner: without it the customer cannot tell whether a
          // gift is out of reach or the app simply never asked.
          if (balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(s.pointsValue(balance), style: AppText.h2.copyWith(fontSize: 15))),
            )
          else if (loyalty.loadingAccount)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onBrand),
                ),
              ),
            )
          else if (context.watch<AuthProvider>().isSignedIn && !loyalty.unavailable)
            IconButton(
              tooltip: s.retry,
              icon: const HugeIcon(icon: AppIcons.refresh, color: AppColors.onBrand, size: 20),
              onPressed: () => context.read<LoyaltyProvider>().loadAccount(),
            ),
        ],
      ),
      body: _body(context, loyalty, s),
    );
  }

  Widget _body(BuildContext context, LoyaltyProvider loyalty, AppStrings s) {
    if (loyalty.loadingGifts && loyalty.gifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // A failure the customer can retry. "This server has no gift shop" never
    // reaches here — the Profile row that opens this screen is itself
    // hidden when the feature is absent.
    if (loyalty.giftsError != null && loyalty.gifts.isEmpty) {
      return _Retry(message: s.orderStateChanged, onRetry: () => context.read<LoyaltyProvider>().loadGifts());
    }
    if (loyalty.gifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(s.giftShopEmpty, textAlign: TextAlign.center, style: AppText.bodyMuted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<LoyaltyProvider>().loadGifts(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: loyalty.gifts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final gift = loyalty.gifts[index];
          return _GiftCard(gift: gift, onAdd: () => _add(gift));
        },
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.gift, required this.onAdd});

  final LoyaltyGift gift;
  final VoidCallback onAdd;

  /// The cart's own refusal, worded for this screen.
  ///
  /// Signing in is deliberately not one of these. A guest browsing the shop
  /// should be invited to sign in by tapping, not stonewalled by a dead
  /// button — that refusal is handled in `_add`.
  static String? reasonText(GiftBlock block, AppStrings s) =>
      switch (block.reason) {
        GiftBlockReason.none => null,
        GiftBlockReason.noFood => s.giftNeedsFood,
        GiftBlockReason.limitReached => s.giftLimitReached,
        GiftBlockReason.notEnoughPoints =>
          s.giftNotEnoughPoints(block.shortfall),
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    final inCart = cart.giftQuantityOf(gift.id);
    final block = cart.giftBlock(
      gift,
      balance: context.watch<LoyaltyProvider>().balance,
    );
    // Sold out is drawn across the thumbnail already, so it does not repeat
    // itself as a line of text under the price.
    final reason = gift.isSoldOut ? null : reasonText(block, s);
    final canAdd = !gift.isSoldOut && block.allowed;

    return Container(
      // Same card language as the dish grid: white on the warm background,
      // lifted by a soft shadow rather than an outline.
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          _GiftThumb(url: gift.imageUrl, soldOut: gift.isSoldOut, soldOutLabel: s.giftOutOfStock),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.name,
                  style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (gift.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(gift.description, style: AppText.bodyMuted.copyWith(fontSize: 12, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PointsChip(text: s.pointsValue(gift.pointsCost)),
                          const SizedBox(height: 4),
                          // The stock line gives way to the reason the
                          // button is dead: how many are left matters far
                          // less than why this one cannot be taken.
                          if (reason != null)
                            Text(
                              reason,
                              style: AppText.label.copyWith(
                                fontSize: 11,
                                color: AppColors.orange,
                              ),
                              maxLines: 2,
                            )
                          else
                            _StockLine(gift: gift),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddGiftButton(label: s.addGift, inCart: inCart, onTap: canAdd ? onAdd : null),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The gift photo, inset with its own rounded corners. A sold-out gift is
/// washed out with the reason written across it, so it reads as unavailable
/// before the customer gets as far as the disabled button.
class _GiftThumb extends StatelessWidget {
  const _GiftThumb({required this.url, required this.soldOut, required this.soldOutLabel});

  final String? url;
  final bool soldOut;
  final String soldOutLabel;

  static const _size = 92.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.cream,
              child: _GiftImage(url: url),
            ),
            if (soldOut)
              ColoredBox(
                color: AppColors.white.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      soldOutLabel,
                      style: AppText.label.copyWith(color: AppColors.white, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  const _PointsChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(icon: AppIcons.star, color: AppColors.goldInk, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AppText.chip.copyWith(color: AppColors.goldInk, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// How many are left. "No limit" is a real state the API sends as
/// `stock: null`, not a number nobody filled in. The last few are flagged in
/// orange — that's the one stock figure worth a customer's attention.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.gift});

  final LoyaltyGift gift;

  static const _lowStock = 5;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final String text;
    final Color color;
    if (gift.isSoldOut) {
      text = s.giftOutOfStock;
      color = AppColors.red;
    } else if (gift.isUnlimited) {
      text = s.giftUnlimited;
      color = AppColors.textSecondary;
    } else {
      text = s.giftsLeft(gift.stock!);
      color = gift.stock! <= _lowStock ? AppColors.orange : AppColors.textSecondary;
    }
    return Text(
      text,
      style: AppText.label.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A brand pill like the dish card's quick-add, with the number already in
/// the cart riding on its corner. Disabled, it goes flat and grey instead of
/// just dimming, so it can't be mistaken for a pressable yellow.
class _AddGiftButton extends StatelessWidget {
  const _AddGiftButton({required this.label, required this.inCart, required this.onTap});

  final String label;
  final int inCart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = enabled ? AppColors.onBrand : AppColors.textMuted;

    return Badge(
      isLabelVisible: inCart > 0,
      label: Text('$inCart'),
      backgroundColor: AppColors.textPrimary,
      textColor: AppColors.white,
      offset: const Offset(-2, -4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: [if (enabled) BoxShadow(color: AppColors.brand.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: enabled ? AppColors.brand : AppColors.divider,
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(icon: AppIcons.plus, color: foreground, size: 16),
                  const SizedBox(width: 4),
                  Text(label, style: AppText.button.copyWith(fontSize: 13, color: foreground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftImage extends StatelessWidget {
  const _GiftImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null || value.isEmpty) return const BrandShimmerBox();
    return CachedNetworkImage(
      imageUrl: value,
      cacheManager: CatalogImageCacheManager.instance,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => const BrandShimmerBox(),
      errorWidget: (_, _, _) => const BrandShimmerBox(),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: AppText.bodyMuted),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(context.s.retry)),
        ],
      ),
    ),
  );
}
