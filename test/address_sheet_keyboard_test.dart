import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/localization/locale_provider.dart';
import 'package:food_delivery/core/models/delivery_address.dart';
import 'package:food_delivery/core/network/api_client.dart';
import 'package:food_delivery/core/services/geocoding_service.dart';
import 'package:food_delivery/core/services/location_service.dart';
import 'package:food_delivery/core/services/tile_cache_service.dart';
import 'package:food_delivery/modules/checkout/address_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Klavye acikken alt panel onun ustune cikmali. `resizeToAvoidBottomInset`
/// bilerek kapali oldugu icin bu is panelin kendi alt boslugu ile yapiliyor —
/// eksik oldugunda jaý/öý alanlarina yazarken panel klavyenin arkasinda
/// kaliyordu.
void main() {
  const keyboard = 320.0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Harita karo onbellegi uygulama destek dizinini istiyor; testte o kanal
    // yok, gecici dizine yonlendiriyoruz.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('tiles').path,
    );
    await TileCacheService.init();
  });

  Future<double> noteFieldBottom(WidgetTester tester, double inset) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Gercek bir telefon yuzeyi: varsayilan test penceresi 800x600 ve
    // MediaQuery'yi sarmak yuzeyi degistirmiyor.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ChangeNotifierProvider(create: (_) => LocationService()),
          Provider(create: (_) => GeocodingService(api: ApiClient())),
        ],
        child: const MaterialApp(
          home: AddressPickerScreen(
            initial: DeliveryAddress(
              district: 'Parahat 7',
              house: '12',
              point: LatLng(37.9, 58.3),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Panelin kendi alt kenari: "klavyenin arkasinda kaliyor mu" sorusunun
    // dogrudan olcusu. Kaydet dugmesini olcmek yaniltiyordu — panel kaydirma
    // alani icerdigi icin dugme gorunur olmasa da yukari kaymis gorunebiliyor.
    final sheet = find
        .ancestor(
          of: find.text('Указать на карте'),
          matching: find.byType(Container),
        )
        .last;
    final bottom = tester.getBottomLeft(sheet).dy;

    // Ekrani kapatip haritanin/ekranin biraktigi zamanlayicilari bosalt,
    // yoksa test sonunda "Timer is still pending" ile duser.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    return bottom;
  }

  testWidgets('haritaya dokununca klavye kapaniyor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ChangeNotifierProvider(create: (_) => LocationService()),
          Provider(create: (_) => GeocodingService(api: ApiClient())),
        ],
        child: const MaterialApp(
          home: AddressPickerScreen(
            initial: DeliveryAddress(
              district: 'Parahat 7',
              house: '12',
              point: LatLng(37.9, 58.3),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Paneldeki bir alana odaklan (not alani her zaman gorunur).
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue, reason: 'klavye acilmaliydi');

    // Haritanin ustune dokun: ekranin ust yarisi harita.
    await tester.tapAt(const Offset(195, 300));
    await tester.pump();
    expect(
      tester.testTextInput.isVisible,
      isFalse,
      reason: 'haritaya dokununca klavye kapanmali',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('klavye acilinca panel icerigi yukari cikiyor', (tester) async {
    final withoutKeyboard = await noteFieldBottom(tester, 0);
    final withKeyboard = await noteFieldBottom(tester, keyboard);

    expect(
      withoutKeyboard,
      844.0,
      reason: 'klavye yokken panel ekranin altina yaslanmali',
    );
    // Asil sart: panelin alt kenari klavyenin ustunde kalmali.
    expect(
      withKeyboard,
      lessThanOrEqualTo(844 - keyboard + 1),
      reason: 'panel klavyenin arkasinda kaliyor '
          '(alt kenar=$withKeyboard, klavye cizgisi=${844 - keyboard})',
    );
  });
}
