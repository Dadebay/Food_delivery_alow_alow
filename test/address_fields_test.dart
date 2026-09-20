import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/delivery_address.dart';
import 'package:food_delivery/core/models/saved_address.dart';
import 'package:latlong2/latlong.dart';

void main() {
  DeliveryAddress build({String house = '', String? apartment}) =>
      DeliveryAddress(
        district: 'Köşi, Görogly (2009) köçesi',
        house: house,
        entrance: '2',
        floor: '5',
        apartment: apartment,
        point: const LatLng(37.9, 58.3),
      );

  test('ev numarasi girildiginde API satirina ekleniyor', () {
    expect(
      build(house: '12').apiLine,
      'Köşi, Görogly (2009) köçesi, 12',
    );
  });

  test('ev numarasi bos birakilinca sarkan virgul olusmuyor', () {
    expect(build().apiLine, 'Köşi, Görogly (2009) köçesi');
    expect(build(house: '   ').apiLine, isNot(endsWith(',')));
  });

  test('adres satirindaki fazla virguller temizleniyor', () {
    // Geocoder bos alanlari da birlestirdiginde olusan gercek bicimler.
    expect(
      DeliveryAddress.tidyLine('Köşi, Görogly (2009) köçesi, , ,'),
      'Köşi, Görogly (2009) köçesi',
    );
    expect(DeliveryAddress.tidyLine('Aşgabat,,,Parahat 7'), 'Aşgabat, Parahat 7');
    expect(DeliveryAddress.tidyLine(' , Parahat 7 , '), 'Parahat 7');
    expect(DeliveryAddress.tidyLine('Parahat  7,   Görogly'), 'Parahat 7, Görogly');
    // Tek ve yerinde duran virgule dokunulmamali.
    expect(
      DeliveryAddress.tidyLine('Aşgabat, Görogly köçesi'),
      'Aşgabat, Görogly köçesi',
    );
  });

  test('kirli satir API govdesine de temiz gidiyor', () {
    final a = DeliveryAddress(
      district: 'Köşi, Görogly köçesi, , ',
      house: '12',
      point: const LatLng(37.9, 58.3),
    );
    expect(a.apiLine, 'Köşi, Görogly köçesi, 12');
  });

  test('once kaydedilmis kirli adres okunurken temizleniyor', () {
    // Ekran goruntusundeki gercek deger: duzeltmeden once kaydedilmis kayit.
    final saved = SavedAddress.fromJson({
      'id': 'a1',
      'label': null,
      'isActive': true,
      'address': 'Mkr. Köpetdag etraby, Berzeňňi, Berzeňňi köçesi, , , , , , ,, ,',
      'latitude': 37.9,
      'longitude': 58.3,
    });
    expect(
      saved.address.district,
      'Mkr. Köpetdag etraby, Berzeňňi, Berzeňňi köçesi',
    );

    // Yerel (Hive) kayittan okuma yolu da ayni.
    final local = DeliveryAddress.fromJson({
      'district': 'Parahat 7, , ,',
      'house': '',
      'lat': 37.9,
      'lng': 58.3,
    });
    expect(local.district, 'Parahat 7');
  });

  test('girelge/gat/oy degerleri modelde korunuyor', () {
    final a = build(house: '12', apartment: '44');
    expect(a.entrance, '2');
    expect(a.floor, '5');
    expect(a.apartment, '44');
    // Yerel kayit (Hive) da bunlari tasimali, yoksa uygulama yeniden
    // acildiginda alanlar bos donerdi.
    final roundTrip = DeliveryAddress.fromJson(a.toJson());
    expect(roundTrip.entrance, '2');
    expect(roundTrip.floor, '5');
    expect(roundTrip.apartment, '44');
    expect(roundTrip.house, '12');
  });
}
