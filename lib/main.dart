import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/auth_repository.dart';
import 'core/data/address_repository.dart';
import 'core/data/catalog_repository.dart';
import 'core/data/contact_repository.dart';
import 'core/data/marketing_repository.dart';
import 'core/data/order_repository.dart';
import 'core/localization/locale_provider.dart';
import 'core/network/api_client.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/geocoding_service.dart';
import 'core/services/location_service.dart';
import 'core/services/push_device_registration_service.dart';
import 'core/services/tile_cache_service.dart';
import 'modules/auth/auth_provider.dart';
import 'modules/cart/cart_provider.dart';
import 'modules/catalog/catalog_provider.dart';
import 'modules/home/banner_provider.dart';
import 'modules/checkout/address_provider.dart';
import 'modules/onboarding/onboarding_provider.dart';
import 'modules/orders/order_provider.dart';
import 'modules/shell/tab_switcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  await Hive.initFlutter();
  await TileCacheService.init();
  final prefs = await SharedPreferences.getInstance();

  // Wiring is done here rather than in a service locator: the graph is small
  // and being able to read it top to bottom is worth more than the indirection.
  final api = ApiClient();
  final connectivity = ConnectivityService();
  final location = LocationService();

  final pushDevices = PushDeviceRegistrationService(api: api);
  final authRepository = AuthRepository(
    api: api,
    prefs: prefs,
    pushDevices: pushDevices,
  );
  api.onUnauthorized = authRepository.refreshSession;

  // After `pushDevices` exists, so a rotated token can be re-sent to the
  // backend the moment FCM issues one — see FirebaseMessagingService.
  await FirebaseMessagingService.instance.initialize(
    onTokenRefresh: pushDevices.register,
  );
  final catalogRepository = CatalogRepository(api: api);
  final addressRepository = AddressRepository(api: api);
  final marketingRepository = MarketingRepository(api: api);
  final contactRepository = ContactRepository(api: api);
  final orderRepository = OrderRepository(api: api);
  final geocodingService = GeocodingService(api: api);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivity),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)),
        ChangeNotifierProvider(
          create: (_) =>
              CatalogProvider(repository: catalogRepository, prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => BannerProvider(repository: marketingRepository),
        ),
        Provider.value(value: contactRepository),
        Provider.value(value: geocodingService),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => AddressProvider(repository: addressRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(repository: orderRepository),
        ),
        ChangeNotifierProvider(create: (_) => TabSwitcher()),
      ],
      child: const FoodDeliveryApp(),
    ),
  );
}
