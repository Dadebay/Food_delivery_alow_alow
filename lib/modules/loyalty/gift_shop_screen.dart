import 'package:cached_network_image/cached_network_image.dart';
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
      if (mounted) context.read<LoyaltyProvider>().loadGifts();
    });
  }

  void _add(LoyaltyGift gift) {
    final s = context.sr;
    final cart = context.read<CartProvider>();

    // Three refusals, three different reasons — a single "cannot add" would
    // leave the customer guessing which one they hit.
    if (!context.read<AuthProvider>().isSignedIn) {
      AppSnackBar.show(context, message: s.giftSignInNeeded);
      return;
    }
    if (!cart.canAddGifts) {
      AppSnackBar.show(context, message: s.giftNeedsFood);
      return;
    }
    // Counted against everything already chosen, not this gift alone: three
    // affordable gifts can still add up to more than the balance.
    //
    // A null balance means "not loaded", never "nothing" — blocking on it
    // would refuse a customer who can in fact afford the gift. The server
    // does the spending and rejects it properly if this turns out wrong.
    final balance = context.read<LoyaltyProvider>().balance;
    if (balance != null && cart.giftPoints + gift.pointsCost > balance) {
      AppSnackBar.show(
        context,
        message: s.giftNotEnoughPoints(
          cart.giftPoints + gift.pointsCost - balance,
        ),
      );
      return;
    }
    if (!cart.addGift(gift)) {
      AppSnackBar.show(context, message: s.giftLimitReached);
      return;
    }
    AppSnackBar.show(context, message: s.giftAdded, kind: AppSnackKind.success);
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
          if (balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(s.pointsValue(balance), style: AppText.h2.copyWith(fontSize: 15))),
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cart = context.watch<CartProvider>();
    final inCart = cart.giftQuantityOf(gift.id);
    final canAdd = cart.canAddGifts && !gift.isSoldOut;

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
