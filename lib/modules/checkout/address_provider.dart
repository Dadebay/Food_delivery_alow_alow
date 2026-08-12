import 'package:flutter/foundation.dart';

import '../../core/models/delivery_address.dart';
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

  DeliveryAddress? get address => _address;
  List<SavedAddress> get saved => _saved;
  bool get loading => _loading;

  void set(DeliveryAddress address) {
    _address = address;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _saved = await _repository.list();
      final active = _saved.where((item) => item.isActive).firstOrNull;
      if (active != null) _address = active.address;
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
