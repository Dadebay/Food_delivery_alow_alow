import 'package:latlong2/latlong.dart';

import '../../models/dish.dart';

/// Demo catalogue — the exact dishes shown in the approved mock-up
/// (`Naharym-mockups-RU/cust_home.png`), plus enough extra items across the
/// category chips shown there to make browsing feel real.
///
/// Each dish's [Dish.imageUrl] points at `assets/images/dishes/<id>.jpg` —
/// drop the real photo in under that name and it appears everywhere the dish
/// is shown, no code change needed. Until then `DishThumbnail` shows a plain
/// neutral tile.
///
/// Lets the whole ordering flow be demonstrated before the backend exists.
/// Flip [AppConfig.useMockData] to `false` to switch every repository call
/// over to the real server.
class MockData {
  const MockData._();

  /// Parahat branch — where every order is cooked and every courier route
  /// starts from. Matches the courier app's branch point exactly.
  static final LatLng branchPoint = LatLng(37.9265, 58.4055);
  static const String branchName = 'Parahat';

  /// There's no name field behind the phone-only auth yet (proposal slide 5
  /// doesn't collect one) — this fills the identity card so it doesn't read
  /// as empty while that's still true.
  static const String customerName = 'Merdan Amanow';

  static const List<DishCategory> categories = [
    DishCategory(id: 'plov', name: 'Плов'),
    DishCategory(id: 'shashlyk', name: 'Шашлык'),
    DishCategory(id: 'somsa', name: 'Самса'),
    DishCategory(id: 'bread', name: 'Выпечка'),
    DishCategory(id: 'salads', name: 'Салаты'),
    DishCategory(id: 'drinks', name: 'Напитки'),
  ];

  static String _image(String id) => 'assets/images/dishes/$id.jpg';

  static List<Dish> dishes() => [
    Dish(
      id: 'somsa-meat',
      name: 'Мясная самса',
      description:
          'Слоёное тесто, рубленая баранина, лук, специи. Выпекается в тандыре.',
      price: 32,
      categoryId: 'somsa',
      imageUrl: _image('somsa-meat'),
      discountPercent: 15,
      portionLabel: '4 шт',
      prepMinutes: 20,
      isFavorite: true,
    ),
    Dish(
      id: 'shashlyk-beef',
      name: 'Шашлык из говядины',
      description: 'Маринованная говяжья вырезка на углях, подаётся с луком.',
      price: 62,
      categoryId: 'shashlyk',
      imageUrl: _image('shashlyk-beef'),
      portionLabel: '3 шампура',
      prepMinutes: 25,
    ),
    Dish(
      id: 'churek',
      name: 'Тандырный чурек',
      description: 'Свежая выпечка из тандыра, подаётся горячим.',
      price: 9,
      categoryId: 'bread',
      imageUrl: _image('churek'),
      portionLabel: 'Свежая выпечка',
    ),
    Dish(
      id: 'byorek-meat',
      name: 'Мясной бёрек',
      description:
          'Тонкое тесто со слоями рубленого мяса, запечённое до корочки.',
      price: 15,
      categoryId: 'bread',
      imageUrl: _image('byorek-meat'),
      portionLabel: '8 кусков',
      prepMinutes: 30,
      isFavorite: true,
    ),
    Dish(
      id: 'plov-ashgabat',
      name: 'Плов по-ашхабадски',
      description:
          'Рис, баранина, морковь, айва — на казане, с бараньим жиром.',
      price: 45,
      categoryId: 'plov',
      imageUrl: _image('plov-ashgabat'),
      portionLabel: '1 порция',
      prepMinutes: 35,
    ),
    Dish(
      id: 'plov-chicken',
      name: 'Плов с курицей',
      description: 'Более лёгкий вариант плова — рис, куриное бедро, зира.',
      price: 38,
      categoryId: 'plov',
      imageUrl: _image('plov-chicken'),
      discountPercent: 10,
      portionLabel: '1 порция',
      prepMinutes: 30,
    ),
    Dish(
      id: 'shashlyk-lamb',
      name: 'Шашлык из баранины',
      description: 'Классика — курдючная баранина, минимум специй.',
      price: 68,
      categoryId: 'shashlyk',
      imageUrl: _image('shashlyk-lamb'),
      discountPercent: 20,
      portionLabel: '3 шампура',
      prepMinutes: 25,
    ),
    Dish(
      id: 'lagman',
      name: 'Лагман',
      description: 'Тянутая лапша, говядина, овощи, наваристый бульон.',
      price: 40,
      categoryId: 'plov',
      imageUrl: _image('lagman'),
      discountPercent: 12,
      portionLabel: '1 порция',
      prepMinutes: 25,
    ),
    Dish(
      id: 'salad-merjen',
      name: 'Салат «Мерджен»',
      description: 'Свежие овощи, зелень, лёгкая заправка.',
      price: 24,
      categoryId: 'salads',
      imageUrl: _image('salad-merjen'),
      portionLabel: 'Свежий',
    ),
    Dish(
      id: 'dograma',
      name: 'Дограма',
      description:
          'Традиционное туркменское блюдо — чурек, мясо, лук на бульоне.',
      price: 38,
      categoryId: 'salads',
      imageUrl: _image('dograma'),
      portionLabel: '1 порция',
      prepMinutes: 15,
    ),
    Dish(
      id: 'ayran',
      name: 'Айран',
      description: 'Холодный кисломолочный напиток.',
      price: 5,
      categoryId: 'drinks',
      imageUrl: _image('ayran'),
      portionLabel: '0.5 л',
    ),
    Dish(
      id: 'tea-green',
      name: 'Чай зелёный',
      description: 'Подаётся горячим, в чайнике на двоих.',
      price: 9,
      categoryId: 'drinks',
      imageUrl: _image('tea-green'),
      portionLabel: 'Чайник',
    ),
    Dish(
      id: 'compote',
      name: 'Компот',
      description: 'Домашний компот из сухофруктов.',
      price: 8,
      categoryId: 'drinks',
      imageUrl: _image('compote'),
      portionLabel: '0.4 л',
    ),
  ];

  /// The weekly promo shown as the banner carousel on the home screen.
  static const List<
    ({String title, String subtitle, String code, int discount})
  >
  promos = [
    (
      title: 'Мясная самса + бёрек',
      subtitle: 'Скидка этой недели',
      code: 'SOMSA15',
      discount: 15,
    ),
  ];

  /// Partner promo banners shown as a swipeable carousel at the top of the
  /// home feed. Drop the image files into `assets/images/banners/` with
  /// these exact names (jpg or png both work — just keep the base name) and
  /// they'll show up automatically; missing files fall back to a plain
  /// colour tile instead of crashing.
  static const List<String> bannerImages = [
    'assets/images/banners/banner_1.png',
    'assets/images/banners/banner_2.png',
    'assets/images/banners/banner_3.png',
    'assets/images/banners/banner_4.png',
    'assets/images/banners/banner_5.png',
    'assets/images/banners/banner_6.png',
  ];
}
