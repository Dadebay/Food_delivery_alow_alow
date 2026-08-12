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
    } finally {
      notifyListeners();
    }
  }
}
