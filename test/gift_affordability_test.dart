import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/dish.dart';
import 'package:food_delivery/core/models/loyalty_gift.dart';
import 'package:food_delivery/modules/cart/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cola = LoyaltyGift(
    id: 'cola',
    name: 'Coca-Cola',
    description: '',
    pointsCost: 40,
  );
  const baklava = LoyaltyGift(
    id: 'baklava',
    name: 'Пахлава',
    description: '',
    pointsCost: 120,
  );

  final kebab = Dish(
    id: 'kebab',
    name: 'Kebab',
    description: '',
    price: 30,
    categoryId: 'grill',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  CartProvider cartWithFood() => CartProvider()..add(kebab);

  group('points gate', () {
    test('a customer with no points at all cannot take a gift', () {
      final cart = cartWithFood();
      final block = cart.giftBlock(cola, balance: 0);

      expect(block.allowed, isFalse);
      expect(block.reason, GiftBlockReason.notEnoughPoints);
      expect(block.shortfall, 40);
      // And the change itself is refused, not only the button greyed out.
      expect(cart.addGift(cola, balance: 0), isFalse);
      expect(cart.gifts, isEmpty);
    });

    test('one point short is still short', () {
      final cart = cartWithFood();
      expect(cart.giftBlock(cola, balance: 39).shortfall, 1);
      expect(cart.addGift(cola, balance: 39), isFalse);
    });

    test('exactly enough is enough', () {
      final cart = cartWithFood();
      expect(cart.giftBlock(cola, balance: 40).allowed, isTrue);
      expect(cart.addGift(cola, balance: 40), isTrue);
      expect(cart.gifts.single.gift.id, 'cola');
    });

    test('the balance is measured against the whole cart, not one gift', () {
      // 60 points buys one 40-point gift but not a second.
      final cart = cartWithFood();
      expect(cart.addGift(cola, balance: 60), isTrue);

      final block = cart.giftBlock(cola, balance: 60);
      expect(block.reason, GiftBlockReason.notEnoughPoints);
      expect(block.shortfall, 20, reason: '80 wanted against 60 held');
      expect(cart.addGift(cola, balance: 60), isFalse);
      expect(cart.giftQuantityOf('cola'), 1);
    });

    test('an affordable gift stays available after an unaffordable one', () {
      final cart = cartWithFood();
      expect(cart.giftBlock(baklava, balance: 60).allowed, isFalse);
      expect(cart.giftBlock(cola, balance: 60).allowed, isTrue);
    });
  });

  group('an unknown balance is not zero', () {
    test('a balance that has not loaded lets the attempt through', () {
      // Null means "not read yet". Refusing on it would block a customer who
      // can in fact afford the gift; the server prices the order for real.
      final cart = cartWithFood();
      expect(cart.giftBlock(cola, balance: null).allowed, isTrue);
      expect(cart.addGift(cola), isTrue);
    });
  });

  group('the other refusals still come first', () {
    test('no food in the cart beats any balance', () {
      final cart = CartProvider();
      expect(cart.giftBlock(cola, balance: 10000).reason,
          GiftBlockReason.noFood);
      expect(cart.addGift(cola, balance: 10000), isFalse);
    });

    test('ten of one gift is the ceiling even with points to spare', () {
      final cart = cartWithFood();
      for (var i = 0; i < CartProvider.maxGiftQuantity; i++) {
        expect(cart.addGift(cola, balance: 100000), isTrue);
      }
      expect(cart.giftBlock(cola, balance: 100000).reason,
          GiftBlockReason.limitReached);
    });

    test('ten distinct gifts is the ceiling for a new one', () {
      final cart = cartWithFood();
      for (var i = 0; i < CartProvider.maxDistinctGifts; i++) {
        final gift = LoyaltyGift(
          id: 'g$i',
          name: 'g$i',
          description: '',
          pointsCost: 1,
        );
        expect(cart.addGift(gift, balance: 100000), isTrue);
      }
      expect(cart.giftBlock(cola, balance: 100000).reason,
          GiftBlockReason.limitReached);
    });
  });
}
