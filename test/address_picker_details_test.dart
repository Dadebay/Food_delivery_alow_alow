import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/localization/app_strings.dart';
import 'package:food_delivery/core/models/delivery_address.dart';
import 'package:latlong2/latlong.dart';

/// Jaý/girelge/gat/öý bolumunun acilis durumu: kayitli bir adres
/// duzenleniyorsa acik, yeni adres girilirken kapali olmali.
bool detailsExpandedFor(DeliveryAddress? initial) =>
    (initial?.house.isNotEmpty ?? false) ||
    (initial?.entrance?.isNotEmpty ?? false) ||
    (initial?.floor?.isNotEmpty ?? false) ||
    (initial?.apartment?.isNotEmpty ?? false);

void main() {
  const point = LatLng(37.9, 58.3);

  test('yeni adreste bolum kapali baslar', () {
    expect(detailsExpandedFor(null), isFalse);
    expect(
      detailsExpandedFor(
        const DeliveryAddress(district: 'Parahat 7', house: '', point: point),
      ),
      isFalse,
    );
  });

  test('kayitli degerler varsa bolum acik baslar', () {
    expect(
      detailsExpandedFor(
        const DeliveryAddress(district: 'Parahat 7', house: '12', point: point),
      ),
      isTrue,
    );
    // Sadece daire doluysa da acilmali: aksi halde kullanici girdigi degeri
    // goremeden kaydeder.
    expect(
      detailsExpandedFor(
        const DeliveryAddress(
          district: 'Parahat 7',
          house: '',
          apartment: '44',
          point: point,
        ),
      ),
      isTrue,
    );
  });

  test('acma/kapama metinleri iki dilde de tanimli', () {
    for (final s in const <AppStrings>[StringsRu(), StringsTm()]) {
      expect(s.addressDetailsShow.trim(), isNotEmpty);
      expect(s.addressDetailsHide.trim(), isNotEmpty);
      expect(s.addressDetailsShow, isNot(s.addressDetailsHide));
    }
  });
}
