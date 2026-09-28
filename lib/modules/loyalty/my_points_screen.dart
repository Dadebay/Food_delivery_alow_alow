import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/loyalty_account.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import 'gift_shop_screen.dart';
import 'loyalty_provider.dart';

/// The customer's point balance and what moved it.
///
/// The balance shown is the server's own number, never the sum of the
/// entries below it: the history is the last few operations rather than the
/// whole ledger, so adding it up would disagree with what the server will
/// actually charge against. It can also be negative — cancelling an order
/// whose points were already credited takes them back — and that is shown
/// as it arrives rather than clamped to zero.
class MyPointsScreen extends StatefulWidget {
  const MyPointsScreen({super.key});

  @override
  State<MyPointsScreen> createState() => _MyPointsScreenState();
}

class _MyPointsScreenState extends State<MyPointsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LoyaltyProvider>().loadAccount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final loyalty = context.watch<LoyaltyProvider>();
    final account = loyalty.account;

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(
        title: Text(s.myPoints),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.onBrand),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: loyalty.loadingAccount && account == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<LoyaltyProvider>().loadAccount(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(balance: account?.pointsBalance, s: s),
                  const SizedBox(height: 24),
                  // Liste dogrudan basliyordu; kisa bir baslik, bakiye ile
                  // altindaki satirlarin ayri iki sey oldugunu soyluyor.
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(s.myPointsSubtitle, style: AppText.label),
                  ),
                  if (account == null || account.entries.isEmpty) _EmptyHistory(s: s) else for (final entry in account.entries) ...[_EntryRow(entry: entry, s: s), const SizedBox(height: 8)],
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.s});

  final int? balance;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    // Puani olmayana "sowgat sec" demek anlamsiz; dugme ancak harcayacak bir
    // sey varken cikiyor.
    final canSpend = (balance ?? 0) > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        // Duz sari yerine hafif bir gecis: kart, altindaki beyaz satirlardan
        // bir yuzey olarak ayrilsin.
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.brandLight, AppColors.brand]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(13)),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: AppColors.onBrand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.pointsBalanceLabel, style: AppText.label.copyWith(color: AppColors.brandMuted)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            // Nothing loaded yet reads as a dash, not as zero: "we do not know
            // yet" and "you have none" are very different to a customer about
            // to spend them.
            balance == null ? '—' : s.pointsValue(balance!),
            style: AppText.h1.copyWith(fontSize: 40, color: AppColors.onBrand),
          ),
          if (canSpend) ...[
            const SizedBox(height: 18),
            // Ekranin eksik parcasi buydu: puanlar gorunuyordu ama onlarla ne
            // yapilacagina giden bir yol yoktu — sowgat dukkanina yalnizca
            // profil ekranindan ulasiliyordu.
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.onBrand,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiftShopScreen())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const HugeIcon(icon: HugeIcons.strokeRoundedGift, color: AppColors.brand, size: 19),
                        const SizedBox(width: 9),
                        Text(s.giftShop, style: AppText.button.copyWith(color: AppColors.brand)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.s});

  final LoyaltyEntry entry;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    // The sign comes from the server's own number. Deriving it from the kind
    // would guess wrong the moment a new kind appears.
    final positive = entry.points >= 0;
    final (icon, tint, wash) = _look(entry.kind, positive);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Satirlarin hepsi ayni beyaz kutuydu; kazanilan ile harcanani
          // ayirmak icin rakami okumak gerekiyordu. Ikon ve renk bunu bir
          // bakista soyluyor.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: HugeIcon(icon: icon, color: tint, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(s, entry.kind), style: AppText.h2.copyWith(fontSize: 14)),
                if (entry.createdAt != null) ...[const SizedBox(height: 2), Text('${Fmt.date(entry.createdAt!)} · ${Fmt.time(entry.createdAt!)}', style: AppText.bodyMuted.copyWith(fontSize: 12))],
              ],
            ),
          ),
          Text('${positive ? '+' : ''}${s.pointsValue(entry.points)}', style: AppText.h2.copyWith(fontSize: 15, color: tint)),
        ],
      ),
    );
  }

  /// Ikon, rakam rengi ve ikonun arkasindaki yumusak zemin.
  ///
  /// Isaret sunucunun kendi sayisindan geliyor (bkz. yukarisi), bu yuzden
  /// renk de ona bagli: bilinmeyen bir tur geldiginde bile kazanc yesil,
  /// harcama noturdur.
  static (List<List<dynamic>>, Color, Color) _look(LoyaltyEntryKind kind, bool positive) => switch (kind) {
    LoyaltyEntryKind.earn => (HugeIcons.strokeRoundedArrowUp01, AppColors.success, AppColors.successSoft),
    LoyaltyEntryKind.redeem => (HugeIcons.strokeRoundedGift, AppColors.orange, AppColors.orangeSoft),
    LoyaltyEntryKind.refund => (HugeIcons.strokeRoundedRefresh, AppColors.goldInk, AppColors.goldSoft),
    LoyaltyEntryKind.reverseEarn => (HugeIcons.strokeRoundedArrowDown01, AppColors.red, AppColors.redSoft),
    LoyaltyEntryKind.unknown => (HugeIcons.strokeRoundedCircle, positive ? AppColors.success : AppColors.textSecondary, AppColors.neutralGrey),
  };

  static String _label(AppStrings s, LoyaltyEntryKind kind) => switch (kind) {
    LoyaltyEntryKind.earn => s.loyaltyEntryEarn,
    LoyaltyEntryKind.redeem => s.loyaltyEntryRedeem,
    LoyaltyEntryKind.refund => s.loyaltyEntryRefund,
    LoyaltyEntryKind.reverseEarn => s.loyaltyEntryReverseEarn,
    // A kind this build has never heard of still gets a row rather than
    // crashing the screen the customer opened to check their points.
    LoyaltyEntryKind.unknown => s.loyaltyEntryOther,
  };
}

/// Bos gecmis. Once ortada tek basina duran gri bir cumleydi; simdi ayni
/// kart dilini kullaniyor ve bos olmasinin bir hata degil, henuz bir sey
/// olmamasi oldugunu soyluyor.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: AppColors.neutralGrey, shape: BoxShape.circle),
          child: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: AppColors.textMuted, size: 24),
        ),
        const SizedBox(height: 14),
        Text(s.pointsHistoryEmpty, textAlign: TextAlign.center, style: AppText.bodyMuted),
      ],
    ),
  );
}
