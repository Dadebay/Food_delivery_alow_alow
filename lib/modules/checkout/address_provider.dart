import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_config.dart';
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

  /// The quote for [_address] — `null` until [refreshQuote] resolves. After
  /// that it is either the backend's real district price or this app's
  /// estimate, distinguished by `DeliveryQuote.isFallback`.
  DeliveryQuote? _quote;

  DeliveryAddress? get address => _address;
  List<SavedAddress> get saved => _saved;
  bool get loading => _loading;
  DeliveryQuote? get quote => _quote;

  /// The etrap the last quote matched, if any — sent back as
  /// `deliveryEtrapId` when placing the order so the server charges exactly
  /// the fee just shown instead of re-resolving the coordinates itself.
  int? get deliveryEtrapId => _quote?.etrapId;

  /// The delivery fee for the current address — `null` only before
  /// [refreshQuote] has run at all, or while no address is picked.
  ///
  /// Once it has run this is always a number: the backend's per-district
  /// price when it answered, otherwise [AppConfig.fallbackDeliveryFee]. Check
  /// [quoteIsEstimate] before presenting it as final.
  double? get deliveryFee => _quote?.fee ?? (_quoting ? _lastFee : null);

  /// True when [deliveryFee] is this app's own estimate rather than a price
  /// the server quoted. Screens must mark it as approximate.
  bool get quoteIsEstimate => _quote?.isFallback ?? false;

  void set(DeliveryAddress address) {
    _log('address set  ${_describe(address)} → quote cleared, one is due');
    _address = address;
    _quote = null;
    notifyListeners();
  }

  /// True while a quote request is in the air. The fee shown meanwhile is
  /// the previous answer rather than nothing — see [_lastFee].
  bool _quoting = false;

  /// The last fee the server gave, kept across the clears that an address
  /// change causes. Saving an address runs two quotes back to back (the
  /// picked point, then the copy the server stores), and without this the
  /// row dropped to the flat estimate in between: 15, then 20, then 15
  /// again, in about a second.
  double? _lastFee;

  /// Re-quotes [_address] for [subtotal] against the backend's live
  /// per-etrap pricing. Safe to call repeatedly (e.g. once per checkout
  /// build whenever the address or subtotal changed) — a failed or demo-mode
  /// lookup just falls back to the flat rate.
  Future<void> refreshQuote(double subtotal) async {
    final point = _address?.point;
    if (point == null) {
      if (_quote != null) {
        _quote = null;
        notifyListeners();
      }
      return;
    }
    _log('requesting   ${_describe(_address!)} subtotal=$subtotal');
    _quoting = true;
    notifyListeners();
    final DeliveryQuote? result;
    try {
      result = await _repository.quote(point: point, subtotal: subtotal);
    } finally {
      _quoting = false;
    }
    _log(
      result == null
          ? 'NO ANSWER (mock mode, network error, or non-2xx) → falling back '
                'to the ${AppConfig.fallbackDeliveryFee} '
                '${AppConfig.currency} estimate'
          : 'answer      fee=${result.fee} matched=${result.matched} '
                'etrapId=${result.etrapId} etrap=${result.etrapNameRu}',
    );
    // No answer at all still produces a number now, so checkout can price the
    // order offline instead of stalling on a row that never fills in. It is an
    // estimate and says so — `isFallback` carries that all the way to the UI,
    // and the server prices the order again at creation time regardless.
    _quote = result ?? DeliveryQuote.fallback(subtotal: subtotal);
    _lastFee = _quote!.fee;
    notifyListeners();
  }

  /// Debug only — the address as a human reads it, plus the point the quote
  /// is actually resolved from. The text alone would not say why a district
  /// failed to match; the coordinates alone would not say which address the
  /// customer thought they picked.
  static String _describe(DeliveryAddress address) {
    final detail = address.detailLine(
      entranceLabel: 'entrance',
      floorLabel: 'floor',
      apartmentLabel: 'apt',
    );
    return '"${address.apiLine}"${detail.isEmpty ? '' : ' ($detail)'} '
        '@ ${address.point.latitude},${address.point.longitude}';
  }

  /// Debug only. The delivery fee is the one number on checkout a customer
  /// will argue about, and it passes through two endpoints and a fallback
  /// before it reaches the screen — this makes each step visible in the run
  /// console rather than only in DevTools.
  static void _log(String message) {
    // ANSI: black on bright cyan, then cyan text.
    debugPrint('\x1B[30;106m DELIVERY \x1B[0m \x1B[96m$message\x1B[0m');
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
  /// district/house form) — unless the same point is already on their
  /// saved list, in which case that existing entry is made active again
  /// instead of creating a near-duplicate row.
  Future<void> addNew(DeliveryAddress address, {String? label}) async {
    final existing = _matchingSaved(address.point);
    if (existing != null) {
      await selectSaved(existing);
      return;
    }
    // Make it the active address before the round trip. The customer picked
    // this point deliberately; if saving it to their address book fails they
    // should still be able to order to it, and `load()` below only replaces
    // this when the server actually has an active address of its own.
    set(address);
    await _repository.create(address, label: label);
    // The server makes the new address active on its own — reload rather
    // than guess its id, so `saved` reflects exactly what it stored.
    await load();
  }

  /// A pin dropped within a few metres of an address already on file is the
  /// same place, not a new one — reusing it keeps "adreslerim" from filling
  /// up with a fresh row every time the customer re-confirms the same spot.
  static const _sameSpotEpsilon = 0.0002; // roughly 20m at this latitude

  SavedAddress? _matchingSaved(LatLng point) {
    for (final item in _saved) {
      final p = item.address.point;
      if ((p.latitude - point.latitude).abs() < _sameSpotEpsilon &&
          (p.longitude - point.longitude).abs() < _sameSpotEpsilon) {
        return item;
      }
    }
    return null;
  }

  Future<void> selectSaved(SavedAddress address) async {
    _log(
      'saved address reactivated id=${address.id} '
      '${_describe(address.address)} → quote cleared, one is due',
    );
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
