import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/models/delivery_address.dart';

/// Ekrandaki adres yazma mantiginin iki surumu.
///
/// Eskisi, "kullanicinin elle yazdigi ilceyi ezme" muhafazasini tasiyordu.
/// Ilce alani duzenlenebilir olmaktan cikinca muhafaza koruyacak bir sey
/// bulamadi; geriye yalnizca karsilastirmanin iki tarafi ayrisinca adresi
/// sessizce donduran bir tuzak kaldi.
class _Old {
  String field = '';
  String? lastGeocoded;

  void applyGeocode(String result) {
    final safe = field.isEmpty || field == lastGeocoded;
    if (!safe) return;
    field = DeliveryAddress.tidyLine(result); // temizlenmis
    lastGeocoded = result; // ham -> iki taraf ayrisiyor
  }

  void applySearchPick(String label) {
    field = DeliveryAddress.tidyLine(label); // lastGeocoded guncellenmiyordu
  }
}

class _New {
  String field = '';

  void applyGeocode(String result) => field = DeliveryAddress.tidyLine(result);
  void applySearchPick(String label) => field = DeliveryAddress.tidyLine(label);
}

void main() {
  // Geocoder gercekte bos alanlari da birlestiriyor.
  const first = 'Parahat 7, , ,';
  const second = 'Berzeňňi köçesi, ,';

  test('ESKI: ilk pin birakmadan sonra adres donuyordu', () {
    final o = _Old()..applyGeocode(first);
    expect(o.field, 'Parahat 7');
    o.applyGeocode(second); // pin baska yere tasindi
    expect(o.field, 'Parahat 7', reason: 'hata: adres guncellenmiyordu');
  });

  test('ESKI: arama ile adres secilince pin adresi hic degistirmiyordu', () {
    final o = _Old()..applySearchPick('Köpetdag etraby, ,');
    o.applyGeocode(second);
    expect(o.field, 'Köpetdag etraby', reason: 'hata: pin adresi ezemiyordu');
  });

  test('YENI: pin her tasindiginda adres guncelleniyor', () {
    final n = _New()..applyGeocode(first);
    expect(n.field, 'Parahat 7');
    n.applyGeocode(second);
    expect(n.field, 'Berzeňňi köçesi');
  });

  test('YENI: arama ile secip sonra pini tasimak da calisiyor', () {
    final n = _New()..applySearchPick('Köpetdag etraby, ,');
    expect(n.field, 'Köpetdag etraby');
    n.applyGeocode(second);
    expect(n.field, 'Berzeňňi köçesi');
  });
}
