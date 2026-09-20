import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';

/// `DeliveryMap.didUpdateWidget` icindeki yeniden cerceveleme kosulunun
/// birebir kopyasi. Onemli olan *ne zaman* cerceveledigi: kurye konumu ve yol
/// ilk gorundugunde evet, kurye her kimildadiginda hayir (yoksa kamera
/// kullanicinin kaydirdigi yerden zorla geri ceker).
bool shouldRefit({
  required LatLng? oldCourier,
  required LatLng? newCourier,
  required List<LatLng> oldRoute,
  required List<LatLng> newRoute,
}) {
  final courierArrived = oldCourier == null && newCourier != null;
  final routeArrived = oldRoute.length < 2 && newRoute.length > 1;
  return courierArrived || routeArrived;
}

void main() {
  const a = LatLng(37.90, 58.30);
  const b = LatLng(37.91, 58.31);
  const route = [a, b];

  test('kurye ilk gorundugunde yeniden cerceveleniyor', () {
    expect(
      shouldRefit(
        oldCourier: null,
        newCourier: a,
        oldRoute: const [],
        newRoute: const [],
      ),
      isTrue,
    );
  });

  test('yol ilk geldiginde yeniden cerceveleniyor', () {
    expect(
      shouldRefit(
        oldCourier: a,
        newCourier: a,
        oldRoute: const [],
        newRoute: route,
      ),
      isTrue,
    );
  });

  test('kurye sadece yer degistirdiginde kamera rahat birakiliyor', () {
    expect(
      shouldRefit(
        oldCourier: a,
        newCourier: b,
        oldRoute: route,
        newRoute: route,
      ),
      isFalse,
    );
  });

  test('degisiklik yokken cerceveleme yok', () {
    expect(
      shouldRefit(
        oldCourier: null,
        newCourier: null,
        oldRoute: const [],
        newRoute: const [],
      ),
      isFalse,
    );
  });
}
