import 'package:flutter/foundation.dart';

import '../../core/data/feature_availability.dart';
import '../../core/data/loyalty_repository.dart';
import '../../core/models/loyalty_account.dart';
import '../../core/models/loyalty_gift.dart';

/// The customer's points and the gift catalogue.
///
/// Three states matter and they are not the same thing:
///  * loading — a request is in the air;
///  * failed — the server was reachable but something went wrong, so a retry
///    button makes sense;
///  * [unavailable] — this server build has no loyalty endpoints at all, so
///    the entire feature should stay off the screen rather than show an
///    error the customer can do nothing about.
///
/// The balance is never computed here. It is read from the server and
/// re-read after anything that could have moved it: an order placed,
/// delivered or cancelled.
class LoyaltyProvider extends ChangeNotifier {
  LoyaltyProvider({required LoyaltyRepository repository})
    : _repository = repository;

  final LoyaltyRepository _repository;

  LoyaltyAccount? _account;
  List<LoyaltyGift> _gifts = const [];
  bool _loadingAccount = false;
  bool _loadingGifts = false;
  bool _unavailable = false;
  Object? _giftsError;
  Object? _accountError;

  LoyaltyAccount? get account => _account;
  List<LoyaltyGift> get gifts => _gifts;
  bool get loadingAccount => _loadingAccount;
  bool get loadingGifts => _loadingGifts;

  /// True once any loyalty endpoint has answered "no such route". Latched:
  /// one 404 is enough to know this server does not have the feature, and
  /// re-asking on every screen build would be a request per frame.
  bool get unavailable => _unavailable;

  Object? get giftsError => _giftsError;
  Object? get accountError => _accountError;

  /// The balance to show, or null when there is nothing trustworthy to show
  /// yet. Callers must not substitute zero: "not loaded" and "no points"
  /// look the same to a customer and mean very different things.
  int? get balance => _account?.pointsBalance;

  Future<void> loadGifts() async {
    if (_unavailable || _loadingGifts) return;
    _loadingGifts = true;
    _giftsError = null;
    notifyListeners();
    try {
      _gifts = await _repository.gifts();
    } on FeatureUnavailableException {
      _markUnavailable();
    } catch (error) {
      _giftsError = error;
    } finally {
      _loadingGifts = false;
      notifyListeners();
    }
  }

  /// Requires a signed-in customer; callers check that first. A 401 here
  /// lands in [accountError] like any other failure — the existing auth
  /// flow is what handles re-authentication, not this provider.
  Future<void> loadAccount() async {
    if (_unavailable || _loadingAccount) return;
    _loadingAccount = true;
    _accountError = null;
    notifyListeners();
    try {
      _account = await _repository.me();
    } on FeatureUnavailableException {
      _markUnavailable();
    } catch (error) {
      _accountError = error;
    } finally {
      _loadingAccount = false;
      notifyListeners();
    }
  }

  /// Called after an order is placed, delivered or cancelled — all three
  /// move the balance, and the gift catalogue's stock along with it.
  Future<void> refresh({required bool signedIn}) async {
    if (_unavailable) return;
    await Future.wait([
      loadGifts(),
      if (signedIn) loadAccount(),
    ]);
  }

  /// Forgets the balance on sign-out. The gift catalogue is public and
  /// stays — it is the same list for everyone.
  void clearAccount() {
    if (_account == null) return;
    _account = null;
    notifyListeners();
  }

  void _markUnavailable() {
    _unavailable = true;
    _gifts = const [];
    _account = null;
    if (kDebugMode) {
      debugPrint(
        '[Loyalty] this server has no loyalty endpoints — hiding the feature',
      );
    }
  }
}
