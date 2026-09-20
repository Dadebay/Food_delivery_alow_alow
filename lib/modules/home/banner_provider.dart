import 'package:flutter/foundation.dart';

import '../../core/data/marketing_repository.dart';
import '../../core/models/promotion_banner.dart';

class BannerProvider extends ChangeNotifier {
  BannerProvider({required MarketingRepository repository})
    : _repository = repository;

  final MarketingRepository _repository;
  List<PromotionBanner> _banners = const [];
  List<PromotionBanner> get banners => _banners;

  Future<void> load() async {
    try {
      _banners = await _repository.banners();
    } catch (_) {
      // Banners are decoration: the menu, the cart and checkout all work
      // without them. This runs fire-and-forget from the home screen, so an
      // unreachable API used to surface here as an unhandled exception in the
      // console — a red herring on every offline launch, on top of leaving
      // whatever banners were already loaded untouched anyway.
    } finally {
      notifyListeners();
    }
  }
}
