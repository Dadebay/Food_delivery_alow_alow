import 'package:flutter/foundation.dart';

import '../../core/models/delivery_address.dart';
import '../../core/models/delivery_quote.dart';
import '../../core/models/saved_address.dart';
import '../../core/data/address_repository.dart';

/// The customer's current delivery address — shown in the home header and
/// pre-filled on checkout. `null` until they pick a point on the map at
/// least once; nothing is invented on their behalf.
class AddressProvider extends ChangeNotifier {
  AddressProvider({required AddressRepository repository})
    : _repository = repository;

  final AddressRepository _repository;
  DeliveryAddress? _address;
  List<SavedAddress> _saved = const [];
  bool _loading = false;

  /// The real, district-priced quote for [_address] — `null` until
  /// [refreshQuote] resolves, or when there's nothing better than the flat
  /// fallback rate to show (see [AddressRepository.quote]).
  DeliveryQuote? _quote;

  DeliveryAddress? get address => _address;
  List<SavedAddress> get saved => _saved;
  bool get loading => _loading;
  DeliveryQuote? get quote => _quote;

  /// The etrap the last quote matched, if any — sent back as
  /// `deliveryEtrapId` when placing the order so the server charges exactly
  /// the fee just shown instead of re-resolving the coordinates itself.
  int? get deliveryEtrapId => _quote?.etrapId;

  /// The backend's own per-district delivery fee for the current address —
  /// `null` until [refreshQuote] resolves. Never guessed on the client: a
  /// screen with no live quote yet must show a loading state, not a made-up
  /// number.
  double? get deliveryFee => _quote?.fee;

  void set(DeliveryAddress address) {
    _address = address;
    _quote = null;
    notifyListeners();
  }

  /// Re-quotes [_address] for [subtotal] against the backend's live
  /// per-etrap pricing. Safe to call repeatedly (e.g. once per checkout
  /// build whenever the address or subtotal changed) — a failed or demo-mode
  /// lookup just clears the quote and callers fall back to the flat rate.
  Future<void> refreshQuote(double subtotal) async {
    final point = _address?.point;
    if (point == null) {
      if (_quote != null) {
        _quote = null;
        notifyListeners();
      }
      return;
    }
    final result = await _repository.quote(point: point, subtotal: subtotal);
    debugPrint(
      result == null
          ? '[DeliveryQuote] ${point.latitude},${point.longitude} → '
                'no quote (mock mode, network error, or non-2xx response)'
          : '[DeliveryQuote] ${point.latitude},${point.longitude} → '
                'fee=${result.fee} matched=${result.matched} '
                'etrapId=${result.etrapId} etrap=${result.etrapNameRu}',
    );
    _quote = result;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _saved = await _repository.list();
      final active = _saved.where((item) => item.isActive).firstOrNull;
      if (active != null) {
        _address = active.address;
        _quote = null;
      }
    } catch (_) {
      // This runs fire-and-forget from screen initState callbacks — a
      // network hiccup or an expired session here must not crash whatever
      // screen happened to trigger it. The customer just keeps whatever
      // address state (or lack of it) they already had.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Saves a brand-new address the customer entered by hand (map pin +
  /// district/house form), rather than one already on the saved list.
  Future<void> addNew(DeliveryAddress address, {String? label}) async {
    await _repository.create(address, label: label);
    // The server makes the new address active on its own — reload rather
    // than guess its id, so `saved` reflects exactly what it stored.
    await load();
  }

  Future<void> selectSaved(SavedAddress address) async {
    await _repository.activate(address.id);
    _address = address.address;
    _quote = null;
    _saved = _saved
        .map(
          (item) => SavedAddress(
            id: item.id,
            label: item.label,
            address: item.address,
            isActive: item.id == address.id,
          ),
        )
        .toList();
    notifyListeners();
  }

  Future<void> removeSaved(SavedAddress address) async {
    await _repository.remove(address.id);
    _saved = _saved.where((item) => item.id != address.id).toList();
    if (address.isActive) {
      _address = _saved.where((item) => item.isActive).firstOrNull?.address;
    }
    notifyListeners();
  }
}
