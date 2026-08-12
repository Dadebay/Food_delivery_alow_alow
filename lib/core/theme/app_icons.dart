import 'package:hugeicons/hugeicons.dart';

/// HugeIcons ships its glyphs as raw path data rather than an icon font, so
/// this is the type every icon parameter in the app is declared with.
typedef HugeIconData = List<List<dynamic>>;

/// One name per icon, so a change of icon set is a change to this file.
class AppIcons {
  const AppIcons._();

  // ─── Navigation ──────────────────────────────────────────────
  static const HugeIconData back = HugeIcons.strokeRoundedArrowLeft01;
  static const HugeIconData home = HugeIcons.strokeRoundedHome01;
  static const HugeIconData favorite = HugeIcons.strokeRoundedFavourite;
  static const HugeIconData category = HugeIcons.strokeRoundedGridView;
  static const HugeIconData cart = HugeIcons.strokeRoundedShoppingBag01;
  static const HugeIconData orders = HugeIcons.strokeRoundedInvoice01;
  static const HugeIconData user = HugeIcons.strokeRoundedUser;

  // ─── Actions ─────────────────────────────────────────────────
  static const HugeIconData search = HugeIcons.strokeRoundedSearch01;
  static const HugeIconData notification =
      HugeIcons.strokeRoundedNotification03;
  static const HugeIconData add = HugeIcons.strokeRoundedAdd01;
  static const HugeIconData minus = HugeIcons.strokeRoundedMinusSign;
  static const HugeIconData plus = HugeIcons.strokeRoundedPlusSign;
  static const HugeIconData location = HugeIcons.strokeRoundedLocation01;
  static const HugeIconData myLocation = HugeIcons.strokeRoundedLocationUser03;
  static const HugeIconData expand = HugeIcons.strokeRoundedFullScreen;
  static const HugeIconData star = HugeIcons.strokeRoundedStar;
  static const HugeIconData call = HugeIcons.strokeRoundedCall;
  static const HugeIconData tag = HugeIcons.strokeRoundedTag01;
  static const HugeIconData filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const HugeIconData courier = HugeIcons.strokeRoundedDeliveryTruck01;
  static const HugeIconData signOut = HugeIcons.strokeRoundedLogout01;
  static const HugeIconData map = HugeIcons.strokeRoundedMapsGlobal01;
  static const HugeIconData history = HugeIcons.strokeRoundedClock01;
  static const HugeIconData package = HugeIcons.strokeRoundedPackage;
  static const HugeIconData check = HugeIcons.strokeRoundedTick01;
  static const HugeIconData checkDouble = HugeIcons.strokeRoundedTickDouble01;
  static const HugeIconData cancel = HugeIcons.strokeRoundedCancel01;
  static const HugeIconData delete = HugeIcons.strokeRoundedDelete02;
  static const HugeIconData checkCircle =
      HugeIcons.strokeRoundedCheckmarkCircle02;
  static const HugeIconData money = HugeIcons.strokeRoundedMoney01;
  static const HugeIconData creditCard = HugeIcons.strokeRoundedCreditCard;
  static const HugeIconData discount = HugeIcons.strokeRoundedDiscountTag01;
  static const HugeIconData note = HugeIcons.strokeRoundedStickyNote01;
  static const HugeIconData edit = HugeIcons.strokeRoundedPencilEdit02;
  static const HugeIconData camera = HugeIcons.strokeRoundedCamera01;
  static const HugeIconData gallery = HugeIcons.strokeRoundedImage02;

  /// Generic empty-state glyph (empty cart, empty favorites, empty orders) —
  /// not tied to any specific dish.
  static const HugeIconData emptyState = HugeIcons.strokeRoundedShoppingBag01;

  // ─── Profile ─────────────────────────────────────────────────
  static const HugeIconData language = HugeIcons.strokeRoundedTranslate;
  static const HugeIconData gift = HugeIcons.strokeRoundedGift;
  static const HugeIconData info = HugeIcons.strokeRoundedInformationCircle;
  static const HugeIconData chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const HugeIconData share = HugeIcons.strokeRoundedShare08;
  static const HugeIconData telegram = HugeIcons.strokeRoundedTelegram;
  static const HugeIconData email = HugeIcons.strokeRoundedMail01;
  static const HugeIconData listView = HugeIcons.strokeRoundedListView;

  /// Background watermark for a category card that has no dish photo yet —
  /// keeps the parallax drift visible even on a flat tint.
  static const HugeIconData foodWatermark = HugeIcons.strokeRoundedServingFood;
}
