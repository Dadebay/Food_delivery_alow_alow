/// Every user-facing string in the app.
///
/// Turkmen and Russian ship together from day one (proposal slide 5). Adding a
/// third language means one more subclass — the compiler then lists every
/// string that still needs translating.
abstract class AppStrings {
  const AppStrings();

  String get languageCode;
  String get languageName;

  // ─── Onboarding ──────────────────────────────────────────────
  String get onboardingTitle1;
  String get onboardingSubtitle1;
  String get onboardingTitle2;
  String get onboardingSubtitle2;
  String get onboardingCourierTitle;
  String get onboardingCourierSubtitle;
  String get onboardingNext;
  String get onboardingStart;
  String get chooseLanguage;

  // ─── Bottom nav ──────────────────────────────────────────────
  String get navHome;
  String get navFavorites;
  String get navCart;
  String get navOrders;
  String get navProfile;

  // ─── Home ────────────────────────────────────────────────────
  String get deliveryAddressLabel;
  String get searchHint;
  String get sections;
  String get all;
  String get categoryPopular;
  String minutesShort(int minutes);
  String get noResults;
  String dishesCount(int n);
  String get gridView;
  String get listView;

  // ─── Dish ────────────────────────────────────────────────────
  String get addToCart;
  String get noteHint;
  String get noteLabel;
  String get quantityLabel;
  String get moreFromCategory;
  String fromPrice(String price);
  String get selectVariantFirst;

  // ─── Cart ────────────────────────────────────────────────────
  String get cartTitle;
  String get cartEmpty;
  String get cartEmptyHint;
  String get goToCheckout;
  String cartBarLabel(int count);

  // ─── Checkout ────────────────────────────────────────────────
  String get checkoutTitle;
  String get orderLabel;
  String get changeFromQuestion;
  String get changeFromHint;
  String changeNote(String amount);
  String get noChangeNeeded;
  String get paymentMethodLabel;
  String get payCash;
  String get payCard;
  String get payCardPhase2;
  String get dishesTotal;
  String get deliveryFeeLabel;
  String get discountLabel;
  String get grandTotal;
  String get placeOrder;
  String get selectAddressFirst;
  String get pickOnMap;
  String get houseLabel;
  String get entranceLabel;
  String get floorLabel;
  String get apartmentLabel;
  String get districtLabel;
  String get addressNoteHint;
  String get addressSearchHint;
  String get addressSearchNoResults;
  String get addressSearchOrPin;
  String get alsoKnownAs;
  String get orderPlacedTitle;
  String get orderPlacedHint;
  String get promoCodeLabel;
  String get promoCodeHint;
  String get promoCodePrompt;
  String get promoApply;
  String promoDiscountApplied(String amount);
  String get itemsSummaryLabel;
  String get changeAddress;

  // ─── Orders / history ────────────────────────────────────────
  String get ordersTitle;
  String get ordersEmpty;
  String get ordersEmptyHint;
  String get reorder;
  String orderNumber(int n);
  String get showOnMap;
  String get orderItemsTitle;
  String get deliveryAddressTitle;
  String get cancelOrderAction;
  String get cancelOrderConfirmTitle;
  String get cancelOrderConfirmMessage;
  String get cancelOrderReasonHint;
  String get cancelOrderReasonRequired;
  String get orderCancelledMessage;
  String get orderCancelFailedMessage;
  String get orderCancelTooLateMessage;
  String get orderPlaceFailedMessage;
  String get promoCodeUnavailable;
  String get promoCodeLimitReached;

  // ─── Tracking ────────────────────────────────────────────────
  String get deliveryTimeLabel;
  String get distanceLabel;
  String etaRange(int low, int high);
  String get onlineBadge;
  String get statusPlaced;
  String get statusAccepted;
  String get statusCooked;
  String get statusOnTheWay;
  String get statusDelivered;
  String get statusCancelled;
  String get callCourier;
  String get rateDelivery;
  String get rateSaved;
  String get changeCourierNote;
  String cashLineTracking(String total);

  // ─── Favorites ───────────────────────────────────────────────
  String get favoritesTitle;
  String get favoritesEmpty;
  String get favoritesEmptyHint;

  // ─── Auth ────────────────────────────────────────────────────
  String get loginTitle;
  String get loginSubtitle;
  String get signIn;
  String get signInPromptOrders;
  String get signInPromptProfile;
  String get signInPromptCheckout;
  String get nameLabel;
  String get nameHint;
  String get phoneNumber;
  String get requestCode;
  String get smsCode;
  String get smsCodeHint;
  String get verify;
  String get demoHint;
  String get codeInvalid;

  // ─── Profile ─────────────────────────────────────────────────
  String get profile;
  String get editProfileTitle;
  String get changePhoto;
  String get chooseFromGallery;
  String get takePhoto;
  String get language;
  String get signOut;
  String get signOutConfirmTitle;
  String get signOutConfirmMessage;
  String get deleteAccount;
  String get deleteAccountConfirmTitle;
  String get deleteAccountConfirmMessage;
  String get support;
  String get savedAddresses;
  String get savedAddressesEmpty;
  String get savedAddressesEmptyHint;
  String get activeAddressLabel;
  String get removeAddressLabel;
  String get removeAddressConfirmTitle;
  String get removeAddressConfirmMessage;
  String get addressHome;
  String get addressWork;
  String get addAddress;
  String get promoCodesTitle;
  String get aboutApp;
  String get aboutAppTagline;
  String get appVersionLabel;
  String get rateApp;
  String get rateAppThanks;
  String get inviteFriends;
  String get inviteFriendsHint;

  // ─── Common / errors ─────────────────────────────────────────
  String get retry;
  String get close;
  String get cancel;
  String get save;
  String get loadingHint;
  String get offlineNoConnection;
  String get locationDenied;
  String get locationDeniedHint;
  String get openSettings;
}

class StringsRu extends AppStrings {
  const StringsRu();

  @override
  String get languageCode => 'ru';
  @override
  String get languageName => 'Русский';

  @override
  String get onboardingTitle1 => 'Любимые блюда в одно касание';
  @override
  String get onboardingSubtitle1 =>
      'Плов, шашлык, самса — закажите за 30 секунд';
  @override
  String get onboardingTitle2 => 'Свежие блюда каждый день';
  @override
  String get onboardingSubtitle2 =>
      'Плов, шашлык, самса — и ещё десятки блюд рядом с вами';
  @override
  String get onboardingCourierTitle => 'Курьер всегда на связи';
  @override
  String get onboardingCourierSubtitle =>
      'Следите за доставкой на карте в реальном времени — от кухни до двери';
  @override
  String get onboardingNext => 'Далее';
  @override
  String get onboardingStart => 'Начать';
  @override
  String get chooseLanguage => 'Выберите язык';

  @override
  String get navHome => 'Главная';
  @override
  String get navFavorites => 'Избранное';
  @override
  String get navCart => 'Корзина';
  @override
  String get navOrders => 'Заказы';
  @override
  String get navProfile => 'Профиль';

  @override
  String get deliveryAddressLabel => 'АДРЕС ДОСТАВКИ';
  @override
  String get searchHint => 'Поиск блюда…';
  @override
  String get sections => 'Блюда';
  @override
  String get all => 'Все';
  @override
  String get categoryPopular => 'Популярное';
  @override
  String minutesShort(int minutes) => '$minutes мин';
  @override
  String get noResults => 'Ничего не найдено';
  @override
  String dishesCount(int n) => '$n ${_plural(n, 'блюдо', 'блюда', 'блюд')}';
  @override
  String get gridView => 'Сетка';
  @override
  String get listView => 'Список';

  @override
  String get addToCart => 'В корзину';
  @override
  String get noteHint => 'Например: без лука, поострее…';
  @override
  String get noteLabel => 'Примечание';
  @override
  String get quantityLabel => 'Количество';
  @override
  String get moreFromCategory => 'Ещё из этого раздела';
  @override
  String fromPrice(String price) => 'от $price';
  @override
  String get selectVariantFirst => 'Сначала выберите вариант';

  @override
  String get cartTitle => 'Корзина';
  @override
  String get cartEmpty => 'Корзина пуста';
  @override
  String get cartEmptyHint => 'Добавьте блюда с главной страницы';
  @override
  String get goToCheckout => 'Оформить заказ';
  @override
  String cartBarLabel(int count) =>
      'Корзина · $count ${_plural(count, 'товар', 'товара', 'товаров')}';

  @override
  String get checkoutTitle => 'Оформление заказа';
  @override
  String get orderLabel => 'SARGYT';
  @override
  String get changeFromQuestion => 'Сдача с какой суммы?';
  @override
  String get changeFromHint => 'Например, 200';
  @override
  String changeNote(String amount) => 'Курьер приедет со сдачей $amount';
  @override
  String get noChangeNeeded => 'Без сдачи';
  @override
  String get paymentMethodLabel => 'СПОСОБ ОПЛАТЫ';
  @override
  String get payCash => 'Наличные';
  @override
  String get payCard => 'Карта';
  @override
  String get payCardPhase2 => 'Скоро';
  @override
  String get dishesTotal => 'Блюда';
  @override
  String get deliveryFeeLabel => 'Доставка';
  @override
  String get discountLabel => 'Скидка';
  @override
  String get grandTotal => 'Итого';
  @override
  String get placeOrder => 'Заказать';
  @override
  String get selectAddressFirst => 'Сначала укажите адрес доставки';
  @override
  String get pickOnMap => 'Указать на карте';
  @override
  String get houseLabel => 'дом';
  @override
  String get entranceLabel => 'подъезд';
  @override
  String get floorLabel => 'этаж';
  @override
  String get apartmentLabel => 'кв.';
  @override
  String get districtLabel => 'Мкр.';
  @override
  String get addressNoteHint => 'Например: домофон не работает, позвоните';
  @override
  String get addressSearchHint => 'Найти адрес';
  @override
  String get addressSearchNoResults => 'Ничего не найдено';
  @override
  String get addressSearchOrPin =>
      'Найдите адрес или поставьте маркер на карте';
  @override
  String get alsoKnownAs => 'Также:';
  @override
  String get orderPlacedTitle => 'Заказ оформлен';
  @override
  String get orderPlacedHint =>
      'Оператор уже видит ваш заказ и скоро его примет';
  @override
  String get promoCodeLabel => 'Промокод';
  @override
  String get promoCodeHint => 'Например, WELCOME15';
  @override
  String get promoCodePrompt => 'Есть промокод?';
  @override
  String get promoApply => 'Применить';
  @override
  String promoDiscountApplied(String amount) =>
      'Промокод применён! Скидка $amount';
  @override
  String get itemsSummaryLabel => 'Ваш заказ';
  @override
  String get changeAddress => 'Изменить';

  @override
  String get ordersTitle => 'Мои заказы';
  @override
  String get ordersEmpty => 'Заказов пока нет';
  @override
  String get ordersEmptyHint => 'Здесь появится история ваших заказов';
  @override
  String get reorder => 'Повторить';
  @override
  String orderNumber(int n) => 'Заказ №$n';
  @override
  String get showOnMap => 'Показать на карте';
  @override
  String get orderItemsTitle => 'Состав заказа';
  @override
  String get deliveryAddressTitle => 'Адрес доставки';
  @override
  String get cancelOrderAction => 'Отменить заказ';
  @override
  String get cancelOrderConfirmTitle => 'Отменить заказ?';
  @override
  String get cancelOrderConfirmMessage =>
      'Это действие нельзя отменить. Заказ будет отменён полностью.';
  @override
  String get cancelOrderReasonHint => 'Укажите причину отмены';
  @override
  String get cancelOrderReasonRequired => 'Введите причину отмены';
  @override
  String get orderCancelledMessage => 'Заказ отменён';
  @override
  String get orderCancelFailedMessage =>
      'Не удалось отменить заказ. Попробуйте ещё раз.';
  @override
  String get orderCancelTooLateMessage =>
      'Заказ уже принят в работу — отменить его может только оператор. '
      'Позвоните нам, пожалуйста.';
  @override
  String get orderPlaceFailedMessage =>
      'Не удалось оформить заказ. Попробуйте ещё раз.';
  @override
  String get promoCodeUnavailable => 'Промокод недействителен или истёк';
  @override
  String get promoCodeLimitReached => 'Вы уже использовали этот промокод';

  @override
  String get deliveryTimeLabel => 'ВРЕМЯ ДОСТАВКИ';
  @override
  String get distanceLabel => 'РАССТОЯНИЕ';
  @override
  String etaRange(int low, int high) => '$low–$high минуты';
  @override
  String get onlineBadge => 'Онлайн';
  @override
  String get statusPlaced => 'Заказ оформлен';
  @override
  String get statusAccepted => 'Оператор принял';
  @override
  String get statusCooked => 'Приготовлено на кухне';
  @override
  String get statusOnTheWay => 'Курьер в пути';
  @override
  String get statusDelivered => 'Доставлено';
  @override
  String get statusCancelled => 'Отменён';
  @override
  String get callCourier => 'Позвонить курьеру';
  @override
  String get rateDelivery => 'Оцените доставку';
  @override
  String get rateSaved => 'Спасибо за оценку!';
  @override
  String get changeCourierNote => 'Курьер приедет со сдачей';
  @override
  String cashLineTracking(String total) => 'наличные $total';

  @override
  String get favoritesTitle => 'Избранное';
  @override
  String get favoritesEmpty => 'Пока пусто';
  @override
  String get favoritesEmptyHint =>
      'Нажмите на сердечко у блюда, чтобы добавить сюда';

  @override
  String get loginTitle => 'Вход';
  @override
  String get loginSubtitle => 'Введите номер телефона — пришлём SMS-код';
  @override
  String get signIn => 'Войти';
  @override
  String get signInPromptOrders => 'Войдите, чтобы видеть свои заказы';
  @override
  String get signInPromptProfile => 'Войдите, чтобы открыть профиль';
  @override
  String get signInPromptCheckout => 'Войдите, чтобы оформить заказ';
  @override
  String get nameLabel => 'Ваше имя';
  @override
  String get nameHint => 'Например, Мурат';
  @override
  String get phoneNumber => 'Номер телефона';
  @override
  String get requestCode => 'Получить код';
  @override
  String get smsCode => 'Код из SMS';
  @override
  String get smsCodeHint => 'Введите 6 цифры';
  @override
  String get verify => 'Войти';
  @override
  String get demoHint => 'Демо-режим: код 000000';
  @override
  String get codeInvalid => 'Неверный код, проверьте и попробуйте снова';

  @override
  String get profile => 'Профиль';
  @override
  String get editProfileTitle => 'Изменить имя';
  @override
  String get changePhoto => 'Изменить фото';
  @override
  String get chooseFromGallery => 'Выбрать из галереи';
  @override
  String get takePhoto => 'Сделать фото';
  @override
  String get language => 'Язык';
  @override
  String get signOut => 'Выйти';
  @override
  String get signOutConfirmTitle => 'Выйти из аккаунта?';
  @override
  String get signOutConfirmMessage =>
      'Вы всегда сможете снова войти по номеру телефона.';
  @override
  String get deleteAccount => 'Удалить аккаунт';
  @override
  String get deleteAccountConfirmTitle => 'Удалить аккаунт?';
  @override
  String get deleteAccountConfirmMessage =>
      'Это действие нельзя отменить. Вы будете выведены из аккаунта.';
  @override
  String get support => 'Поддержка';
  @override
  String get savedAddresses => 'Сохранённые адреса';
  @override
  String get savedAddressesEmpty => 'Пока нет сохранённых адресов';
  @override
  String get savedAddressesEmptyHint =>
      'Адрес, который вы укажете при заказе, сохранится здесь автоматически';
  @override
  String get activeAddressLabel => 'Текущий';
  @override
  String get removeAddressLabel => 'Удалить';
  @override
  String get removeAddressConfirmTitle => 'Удалить адрес?';
  @override
  String get removeAddressConfirmMessage => 'Это действие нельзя отменить.';
  @override
  String get addressHome => 'Дом';
  @override
  String get addressWork => 'Работа';
  @override
  String get addAddress => 'Добавить адрес';
  @override
  String get promoCodesTitle => 'Промокоды';
  @override
  String get aboutApp => 'О приложении';
  @override
  String get aboutAppTagline => 'Любимые блюда с доставкой на дом';
  @override
  String get appVersionLabel => 'Версия';
  @override
  String get rateApp => 'Оценить приложение';
  @override
  String get rateAppThanks => 'Спасибо за поддержку!';
  @override
  String get inviteFriends => 'Пригласить друзей';
  @override
  String get inviteFriendsHint => 'Поделитесь кодом FOOD2026 с друзьями';

  @override
  String get retry => 'Повторить';
  @override
  String get close => 'Закрыть';
  @override
  String get cancel => 'Отмена';
  @override
  String get save => 'Сохранить';
  @override
  String get loadingHint => 'Загружаем…';
  @override
  String get offlineNoConnection => 'Нет интернета — работаем офлайн';
  @override
  String get locationDenied => 'Нет доступа к геолокации';
  @override
  String get locationDeniedHint =>
      'Разрешите доступ, чтобы указать адрес на карте.';
  @override
  String get openSettings => 'Настройки';

  /// Russian needs three plural forms.
  static String _plural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    return switch (n % 10) {
      1 => one,
      2 || 3 || 4 => few,
      _ => many,
    };
  }
}

class StringsTm extends AppStrings {
  const StringsTm();

  @override
  String get languageCode => 'tk';
  @override
  String get languageName => 'Türkmençe';

  @override
  String get onboardingTitle1 => 'Halan tagamlaryňyz bir düwmede';
  @override
  String get onboardingSubtitle1 =>
      'Palow, kebap, somsa — 30 sekuntda sargyt ediň';
  @override
  String get onboardingTitle2 => 'Her gün täze tagamlar';
  @override
  String get onboardingSubtitle2 =>
      'Palow, kebap, somsa — we ýene onlarça tagam golaýyňyzda';
  @override
  String get onboardingCourierTitle => 'Kurýer hemişe aragatnaşykda';
  @override
  String get onboardingCourierSubtitle =>
      'Gowşuryşy hakyky wagtda kartada yzarlaň — aşhanadan gapyňyza çenli';
  @override
  String get onboardingNext => 'Indiki';
  @override
  String get onboardingStart => 'Başla';
  @override
  String get chooseLanguage => 'Dil saýlaň';

  @override
  String get navHome => 'Baş sahypa';
  @override
  String get navFavorites => 'Halanan';
  @override
  String get navCart => 'Sebet';
  @override
  String get navOrders => 'Sargytlar';
  @override
  String get navProfile => 'Profil';

  @override
  String get deliveryAddressLabel => 'GOWŞURYŞ SALGYSY';
  @override
  String get searchHint => 'Tagam gözle…';
  @override
  String get sections => 'Tagamlar';
  @override
  String get all => 'Ählisi';
  @override
  String get categoryPopular => 'Meşhur';
  @override
  String minutesShort(int minutes) => '$minutes min';
  @override
  String get noResults => 'Hiç zat tapylmady';
  @override
  String dishesCount(int n) => '$n tagam';
  @override
  String get gridView => 'Tor görnüşi';
  @override
  String get listView => 'Sanaw görnüşi';

  @override
  String get addToCart => 'Sebede goş';
  @override
  String get noteHint => 'Mysal üçin: sogansyz, ýiti bolsun…';
  @override
  String get noteLabel => 'Bellik';
  @override
  String get quantityLabel => 'Sany';
  @override
  String get moreFromCategory => 'Bu bölümden ýene';
  @override
  String fromPrice(String price) => '$price-den başlap';
  @override
  String get selectVariantFirst => 'Ilki görnüşini saýlaň';

  @override
  String get cartTitle => 'Sebet';
  @override
  String get cartEmpty => 'Sebet boş';
  @override
  String get cartEmptyHint => 'Baş sahypadan tagam goşuň';
  @override
  String get goToCheckout => 'Sargyt et';
  @override
  String cartBarLabel(int count) => 'Sebet · $count haryt';

  @override
  String get checkoutTitle => 'Sargydy resmileşdirmek';
  @override
  String get orderLabel => 'SARGYT';
  @override
  String get changeFromQuestion => 'Gaýtargy näçeden gerek?';
  @override
  String get changeFromHint => 'Mysal üçin, 200';
  @override
  String changeNote(String amount) => 'Kurýer $amount-dan gaýtargy bilen geler';
  @override
  String get noChangeNeeded => 'Gaýtargy gerek däl';
  @override
  String get paymentMethodLabel => 'TÖLEG GÖRNÜŞI';
  @override
  String get payCash => 'Nagt';
  @override
  String get payCard => 'Kart';
  @override
  String get payCardPhase2 => 'Ýakynda';
  @override
  String get dishesTotal => 'Tagamlar';
  @override
  String get deliveryFeeLabel => 'Eltip bermek';
  @override
  String get discountLabel => 'Arzanladyş';
  @override
  String get grandTotal => 'Jemi';
  @override
  String get placeOrder => 'Sargyt et';
  @override
  String get selectAddressFirst => 'Ilki gowşuryş salgysyny saýlaň';
  @override
  String get pickOnMap => 'Kartada görkez';
  @override
  String get houseLabel => 'jaý';
  @override
  String get entranceLabel => 'girelge';
  @override
  String get floorLabel => 'gat';
  @override
  String get apartmentLabel => 'öý';
  @override
  String get districtLabel => 'Adres';
  @override
  String get addressNoteHint => 'Mysal üçin: domofon işlänok, jaň ediň';
  @override
  String get addressSearchHint => 'Salgyny gözle';
  @override
  String get addressSearchNoResults => 'Hiç zat tapylmady';
  @override
  String get addressSearchOrPin => 'Salgyny gözläň ýa-da kartada nyşan goýuň';
  @override
  String get alsoKnownAs => 'Şeýle-de:';
  @override
  String get orderPlacedTitle => 'Sargyt kabul edildi';
  @override
  String get orderPlacedHint =>
      'Operator sargydyňyzy görýär, ýakynda kabul eder';
  @override
  String get promoCodeLabel => 'Promokod';
  @override
  String get promoCodeHint => 'Mysal üçin, WELCOME15';
  @override
  String get promoCodePrompt => 'Promokodyňyz barmy?';
  @override
  String get promoApply => 'Ulanmak';
  @override
  String promoDiscountApplied(String amount) =>
      'Promokod ulanyldy! Arzanladyş: $amount';
  @override
  String get itemsSummaryLabel => 'Sargydyňyz';
  @override
  String get changeAddress => 'Üýtget';

  @override
  String get ordersTitle => 'Sargytlarym';
  @override
  String get ordersEmpty => 'Heniz sargyt ýok';
  @override
  String get ordersEmptyHint => 'Sargytlaryňyzyň taryhy şu ýerde peýda bolar';
  @override
  String get reorder => 'Gaýtala';
  @override
  String orderNumber(int n) => 'Sargyt №$n';
  @override
  String get showOnMap => 'Kartada görkez';
  @override
  String get orderItemsTitle => 'Sargydyň düzümi';
  @override
  String get deliveryAddressTitle => 'Gowşuryş salgysy';
  @override
  String get cancelOrderAction => 'Sargydy ýatyr';
  @override
  String get cancelOrderConfirmTitle => 'Sargydy ýatyrmak isleýärsiňizmi?';
  @override
  String get cancelOrderConfirmMessage =>
      'Bu hereketi yzyna gaýtaryp bolmaz. Sargyt doly ýatyrylar.';
  @override
  String get cancelOrderReasonHint => 'Ýatyrmagyň sebäbini ýazyň';
  @override
  String get cancelOrderReasonRequired => 'Ýatyrmagyň sebäbini giriziň';
  @override
  String get orderCancelledMessage => 'Sargyt ýatyryldy';
  @override
  String get orderCancelFailedMessage =>
      'Sargydy ýatyryp bolmady. Täzeden synanyşyň.';
  @override
  String get orderCancelTooLateMessage =>
      'Sargyt eýýäm işe alyndy — ony diňe operator ýatyryp biler. '
      'Bize jaň ediň.';
  @override
  String get orderPlaceFailedMessage =>
      'Sargyt bermek başartmady. Täzeden synanyşyň.';
  @override
  String get promoCodeUnavailable => 'Promokod nädogry ýa-da möhleti geçen';
  @override
  String get promoCodeLimitReached => 'Siz eýýäm bu promokody ulandyňyz';

  @override
  String get deliveryTimeLabel => 'GOWŞURYŞ WAGTY';
  @override
  String get distanceLabel => 'ARALYK';
  @override
  String etaRange(int low, int high) => '$low–$high min';
  @override
  String get onlineBadge => 'Onlaýn';
  @override
  String get statusPlaced => 'Sargyt edildi';
  @override
  String get statusAccepted => 'Operator kabul etdi';
  @override
  String get statusCooked => 'Aşhanada taýýarlandy';
  @override
  String get statusOnTheWay => 'Kurýer ýolda';
  @override
  String get statusDelivered => 'Gowşuryldy';
  @override
  String get statusCancelled => 'Ýatyryldy';
  @override
  String get callCourier => 'Kurýere jaň et';
  @override
  String get rateDelivery => 'Gowşuryşy baha beriň';
  @override
  String get rateSaved => 'Baha üçin sag boluň!';
  @override
  String get changeCourierNote => 'Kurýer gaýtargy bilen geler';
  @override
  String cashLineTracking(String total) => 'nagt $total';

  @override
  String get favoritesTitle => 'Halanan';
  @override
  String get favoritesEmpty => 'Heniz boş';
  @override
  String get favoritesEmptyHint => 'Halan tagamyňyzyň ýürejigine basyň';

  @override
  String get loginTitle => 'Giriş';
  @override
  String get loginSubtitle => 'Telefon belgiňizi giriziň — SMS kody ugradarys';
  @override
  String get signIn => 'Gir';
  @override
  String get signInPromptOrders => 'Sargytlaryňyzy görmek üçin giriň';
  @override
  String get signInPromptProfile => 'Profili açmak üçin giriň';
  @override
  String get signInPromptCheckout => 'Sargyt bermek üçin giriň';
  @override
  String get nameLabel => 'Adyňyz';
  @override
  String get nameHint => 'Mysal üçin, Merdan';
  @override
  String get phoneNumber => 'Telefon belgisi';
  @override
  String get requestCode => 'Kod al';
  @override
  String get smsCode => 'SMS kody';
  @override
  String get smsCodeHint => '6 sany giriziň';
  @override
  String get verify => 'Gir';
  @override
  String get demoHint => 'Demo režim: kod 000000';
  @override
  String get codeInvalid => 'Kod nädogry, barlap gaýtadan synanyşyň';

  @override
  String get profile => 'Profil';
  @override
  String get editProfileTitle => 'Ady üýtgetmek';
  @override
  String get changePhoto => 'Suraty üýtgetmek';
  @override
  String get chooseFromGallery => 'Galereýadan saýlamak';
  @override
  String get takePhoto => 'Surata düşmek';
  @override
  String get language => 'Dil';
  @override
  String get signOut => 'Çyk';
  @override
  String get signOutConfirmTitle => 'Hasapdan çykmak isleýärsiňizmi?';
  @override
  String get signOutConfirmMessage =>
      'Islendik wagt telefon belgiňiz bilen gaýtadan girip bilersiňiz.';
  @override
  String get deleteAccount => 'Hasaby poz';
  @override
  String get deleteAccountConfirmTitle => 'Hasaby pozmak isleýärsiňizmi?';
  @override
  String get deleteAccountConfirmMessage =>
      'Bu hereketi yzyna gaýtaryp bolmaz. Hasabyňyzdan çykarylarsyňyz.';
  @override
  String get support => 'Goldaw';
  @override
  String get savedAddresses => 'Ýatda saklanan salgylar';
  @override
  String get savedAddressesEmpty => 'Entek ýatda saklanan salgy ýok';
  @override
  String get savedAddressesEmptyHint =>
      'Sargyt berende görkezen salgyňyz şu ýerde awtomatiki ýatda saklanar';
  @override
  String get activeAddressLabel => 'Häzirki';
  @override
  String get removeAddressLabel => 'Poz';
  @override
  String get removeAddressConfirmTitle => 'Salgyny pozmak isleýärsiňizmi?';
  @override
  String get removeAddressConfirmMessage =>
      'Bu hereketi yzyna gaýtaryp bolmaz.';
  @override
  String get addressHome => 'Öý';
  @override
  String get addressWork => 'Iş';
  @override
  String get addAddress => 'Salgy goş';
  @override
  String get promoCodesTitle => 'Promokodlar';
  @override
  String get aboutApp => 'Programma barada';
  @override
  String get aboutAppTagline => 'Halan tagamlaryňyz gapyňyza eltilýär';
  @override
  String get appVersionLabel => 'Wersiýa';
  @override
  String get rateApp => 'Programma baha ber';
  @override
  String get rateAppThanks => 'Goldawyňyz üçin sag boluň!';
  @override
  String get inviteFriends => 'Dostlary çagyr';
  @override
  String get inviteFriendsHint => 'FOOD2026 koduny dostlaryňyz bilen paýlaşyň';

  @override
  String get retry => 'Gaýtala';
  @override
  String get close => 'Ýap';
  @override
  String get cancel => 'Ýatyr';
  @override
  String get save => 'Ýatda sakla';
  @override
  String get loadingHint => 'Ýüklenýär…';
  @override
  String get offlineNoConnection => 'Internet ýok — oflaýn işleýäris';
  @override
  String get locationDenied => 'Geolokasiýa rugsat ýok';
  @override
  String get locationDeniedHint => 'Kartada salgy görkezmek üçin rugsat beriň.';
  @override
  String get openSettings => 'Sazlamalar';
}
