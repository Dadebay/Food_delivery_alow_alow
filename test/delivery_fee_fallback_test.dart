import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/constants/app_config.dart';
import 'package:food_delivery/core/models/order_quote.dart';

/// Teslimat ucreti zinciri:
///   sunucu fiyati  ->  yoksa 30 sn sonra yedek (AppConfig.fallbackDeliveryFee)
///
/// Burada olculen sey ekranda gorunen rakam: `/orders/quote` cevap vermezse
/// satir sonsuza kadar "…" kaliyordu, simdi yedek ucrete dusuyor.
double shownDeliveryFee({OrderQuote? quote, required double fallback}) =>
    quote?.deliveryFee ?? fallback;

double shownTotal({
  OrderQuote? quote,
  required double subtotal,
  required double fallback,
}) => quote?.total ?? (subtotal + fallback);

/// Depo katmaninin zaman asimi davranisi: 30 saniyeyi gecen istek null doner,
/// saglayici da yedege duser.
Future<double> feeAfterRequest({
  required Duration serverDelay,
  double? serverFee,
}) async {
  try {
    final fee = await Future<double?>.delayed(serverDelay, () => serverFee)
        .timeout(AppConfig.deliveryQuoteTimeout);
    return fee ?? AppConfig.fallbackDeliveryFee;
  } catch (_) {
    return AppConfig.fallbackDeliveryFee;
  }
}

void main() {
  test('yedek ucret 20 TMT olarak tanimli', () {
    expect(AppConfig.fallbackDeliveryFee, 20);
    expect(AppConfig.deliveryQuoteTimeout, const Duration(seconds: 30));
  });

  test('API cevap vermezse 30 sn sonra yedege dusuyor', () {
    fakeAsync((async) {
      double? result;
      feeAfterRequest(serverDelay: const Duration(minutes: 5)).then((v) => result = v);

      async.elapse(const Duration(seconds: 29));
      expect(result, isNull, reason: '30 sn dolmadan pes etmemeli');

      async.elapse(const Duration(seconds: 2));
      expect(result, 20, reason: '30 sn sonra 20 TMT gosterilmeli');
    });
  });

  test('sunucu zamaninda cevap verirse onun fiyati kullaniliyor', () {
    fakeAsync((async) {
      double? result;
      feeAfterRequest(
        serverDelay: const Duration(seconds: 2),
        serverFee: 35,
      ).then((v) => result = v);
      async.elapse(const Duration(seconds: 3));
      expect(result, 35);
    });
  });

  test('ekran: teklif yokken yedek ucret ve toplam gosteriliyor', () {
    expect(shownDeliveryFee(quote: null, fallback: 20), 20);
    expect(shownTotal(quote: null, subtotal: 80, fallback: 20), 100);
  });
}
