import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/geocoding_result.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/tile_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/details_toggle.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/car_marker.dart';

/// Drop a pin, then fill in the microdistrict details Ashgabat's address
/// system actually runs on (proposal slide 5: "мкр., дом, подъезд, этаж", not
/// a street). Returns the finished [DeliveryAddress] via `Navigator.pop`.
class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({super.key, this.initial});

  final DeliveryAddress? initial;

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const double _pinSize = 44;
  static double get _pinHeight => _pinSize * DestinationPin.heightRatio;

  final MapController _map = MapController();

  late LatLng _center = widget.initial?.point ?? LocationService.fallbackCenter;

  // True only while the map is actively being dragged/pinched — the pin
  // lifts off the map while this is true and drops back once gestures stop,
  // so it reads as physically marking the point instead of sitting static.
  bool _dragging = false;
  Timer? _dragEndTimer;

  late final GeocodingService _geocoder;
  bool _locating = false;

  /// GPS fix'i beklenirken true. Fix birkac saniye surebiliyor ve o sure
  /// boyunca dugme olu goruyordu — basildigini gosteren bir sey yoktu.
  bool _findingLocation = false;

  /// Jaý/girelge/gat/öý alanlari varsayilan olarak kapali: adreslerin cogu
  /// icin doldurulmuyorlar ve acikta durduklarinda panel haritayi yiyor.
  /// Kayitli bir adres duzenleniyorsa acik baslar — aksi halde kullanici
  /// daha once girdigi degerleri goremezdi.
  late bool _showDetails =
      (widget.initial?.house.isNotEmpty ?? false) ||
      (widget.initial?.entrance?.isNotEmpty ?? false) ||
      (widget.initial?.floor?.isNotEmpty ?? false) ||
      (widget.initial?.apartment?.isNotEmpty ?? false);

  /// What geocoding itself last wrote into the district field — as long as
  /// the field still holds exactly this, overwriting it on the next pin
  /// move is safe. The moment it doesn't match, the customer has typed
  /// something of their own, and geocoding stops touching the field.

  late final TextEditingController _district = TextEditingController(
    text: widget.initial?.district ?? '',
  );
  late final TextEditingController _house = TextEditingController(
    text: widget.initial?.house ?? '',
  );
  late final TextEditingController _entrance = TextEditingController(
    text: widget.initial?.entrance ?? '',
  );
  late final TextEditingController _floor = TextEditingController(
    text: widget.initial?.floor ?? '',
  );
  late final TextEditingController _apartment = TextEditingController(
    text: widget.initial?.apartment ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial?.note ?? '',
  );

  // The one place the customer still types free text: a search query, not
  // the address itself. A match they pick fills the district field with a
  // real, mapped place — the same guarantee dragging the pin already gives,
  // just reachable without knowing where on the map to look.
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<GeocodingResult> _searchResults = const [];
  bool _searchAttempted = false;
  bool _searching = false;
  Timer? _searchDebounce;

  /// En son sunucuya sorulan metin. Ayni sorgunun tekrar gitmesini engelliyor
  /// — kullanici bir harf silip geri yazdiginda kotadan bir istek daha
  /// harcanmasin diye.
  String _lastSearchedQuery = '';

  @override
  void initState() {
    super.initState();
    _geocoder = context.read<GeocodingService>();
    for (final c in [_district, _house, _entrance, _floor, _apartment, _note]) {
      c.addListener(_onFieldChanged);
    }
    _search.addListener(_onFieldChanged);
    _search.addListener(_onSearchTextChanged);
    // The bottom sheet hides while this has focus — see `build` — so a
    // focus change alone (not just a keystroke) has to trigger a rebuild.
    _searchFocus.addListener(_onFieldChanged);
    // Yeni adres: haritayi kullanicinin bulundugu yere getir. Kayitli bir
    // adres duzenleniyorsa harita zaten onun uzerinde aciliyor ve pin
    // tasinana kadar adres oldugu gibi kaliyor.
    if (widget.initial == null) _useMyLocation();
  }

  @override
  void dispose() {
    for (final c in [_district, _house, _entrance, _floor, _apartment, _note]) {
      c.dispose();
    }
    _search.dispose();
    _searchFocus.dispose();
    _dragEndTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    _center = position.center;
    if (!hasGesture) return;
    if (!_dragging) setState(() => _dragging = true);
    // flutter_map doesn't fire a distinct "gesture ended" event, so a short
    // debounce after the last moved-with-gesture callback stands in for it.
    _dragEndTimer?.cancel();
    final point = _center;
    _dragEndTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _dragging = false);
      _reverseGeocode(point);
    });
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _locating = true);
    final result = await _geocoder.reverseGeocode(point);
    // A plain `!=` would also reject a match on floating-point noise picked
    // up between here and the point being captured — a hair under a
    // millimetre of drift is still the same point.
    final stillOnPoint =
        (point.latitude - _center.latitude).abs() < 1e-9 &&
        (point.longitude - _center.longitude).abs() < 1e-9;
    if (!mounted || !stillOnPoint) return;
    setState(() {
      _locating = false;
      // Pini tasimak "burasi olsun" demektir: gelen adres kosulsuz yaziliyor.
      // Ilce alani elle doldurulamiyor (bkz. `_ChosenAddressCard`), dolayisiyla
      // ustune yazilacak bir kullanici girdisi de yok.
      if (result != null) _district.text = DeliveryAddress.tidyLine(result);
    });
  }

  /// Starts a search a beat after typing stops, so results appear without
  /// the customer having to reach for the search button.
  ///
  /// The delay is not cosmetic: the backend throttles this endpoint to 10
  /// calls a minute, and firing per keystroke would spend that budget on a
  /// single word. Waiting for the pause, refusing anything under three
  /// characters and skipping a query already asked keeps a normal search to
  /// one request.
  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    final query = _search.text.trim();
    if (query.length < 3) {
      // Below the threshold there is nothing to show, and leaving the last
      // hits up would have them read as matches for what is on screen now.
      if (_searchResults.isNotEmpty || _searchAttempted) {
        setState(() {
          _searchResults = const [];
          _searchAttempted = false;
        });
      }
      return;
    }
    if (query == _lastSearchedQuery) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_runSearch()),
    );
  }

  /// Runs from the debounce above, or straight away on an explicit submit —
  /// the enter key or the search button, which cancel the pending timer so
  /// the same query cannot go twice.
  Future<void> _runSearch() async {
    _searchDebounce?.cancel();
    final query = _search.text.trim();
    if (query.length < 3) return;
    _lastSearchedQuery = query;
    setState(() {
      _searching = true;
      _searchAttempted = true;
    });
    final results = await _geocoder.search(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = results;
    });
  }

  /// The search field's own × — clears the query, drops any stale results
  /// so they can't flash back up if the same text is typed again, and
  /// unfocuses so the keyboard closes and the bottom sheet slides back in.
  void _clearSearch() {
    setState(() {
      _searchResults = const [];
      _searchAttempted = false;
    });
    _search.clear();
    _searchFocus.unfocus();
  }

  /// A search hit is exactly as trustworthy as a dropped pin — it is a real
  /// OSM place, not text the customer typed — so it fills the district
  /// field the same way dragging the pin does.
  void _applySearchResult(GeocodingResult result) {
    setState(() {
      _center = result.point;
      _district.text = DeliveryAddress.tidyLine(result.label);
      _searchResults = const [];
      _searchAttempted = false;
    });
    _search.clear();
    _searchFocus.unfocus();
    _map.move(_center, AppConfig.pickZoom);
  }

  bool get _canSave => _district.text.trim().isNotEmpty;

  /// Fails loudly enough to act on: GPS off or permission refused both make
  /// `fetch()` return null, and saying nothing left the button looking
  /// broken rather than blocked.
  /// Odagi formdan alir. `unfocus` tek basina yetiyor — arama alani odagi
  /// kaybedince paneli geri getiren dinleyici zaten kurulu (bkz. initState).
  void _dismissKeyboard() {
    final focus = FocusScope.of(context);
    if (focus.hasFocus) focus.unfocus();
  }

  Future<void> _useMyLocation() async {
    if (_findingLocation) return;
    setState(() => _findingLocation = true);
    final location = context.read<LocationService>();
    dev.log('my-location button tapped', name: 'AddressPicker');
    // `finally`, so a throw or a disposal mid-lookup still frees the button
    // instead of leaving it spinning on a request nobody is waiting on.
    LatLng? point;
    try {
      point = await location.fetch();
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
    dev.log(
      'fetch -> $point source=${location.lastSource.name} '
      'error=${location.error} approximate=${location.lastResultIsApproximate} '
      'mounted=$mounted',
      name: 'AddressPicker',
    );
    if (!mounted) return;

    if (point == null) {
      final s = context.sr;
      // "No access to geolocation" is only true for two of the four reasons
      // `fetch()` gives up. Indoors the permission is fine and the receiver
      // simply has nothing, and telling the customer to grant a permission
      // they already granted just leaves them stuck in settings.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location.isBlocked
                ? '${s.locationDenied} — ${s.locationDeniedHint}'
                : s.locationNoFix,
          ),
        ),
      );
      return;
    }
    // Coarse *or* remembered: a ten-minute-old point can be a street away,
    // and the pin has to be verified before it becomes a delivery address.
    if (location.lastResultIsApproximate) {
      // A network-based fix can be a couple of streets out. Centring on it is
      // still the right move — it saves the customer the long drag across the
      // city — but it must not look like the app knows their doorstep.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.sr.locationApproximate)));
    }
    final found = point;
    setState(() => _center = found);
    // A programmatic move like this never reaches `_onMapPositionChanged`
    // with `hasGesture: true` — flutter_map only sets that flag for an
    // actual finger drag — so geocoding has to be kicked off by hand here,
    // or the pin's very first, GPS-picked position never gets looked up.
    _map.move(found, AppConfig.pickZoom);
    _reverseGeocode(found);
  }

  void _save() {
    final address = DeliveryAddress(
      district: _district.text.trim(),
      house: _house.text.trim(),
      entrance: _entrance.text.trim().isEmpty ? null : _entrance.text.trim(),
      floor: _floor.text.trim().isEmpty ? null : _floor.text.trim(),
      apartment: _apartment.text.trim().isEmpty ? null : _apartment.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      point: _center,
    );
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      backgroundColor: AppColors.white,
      // The map and the search box above it don't need to move for the
      // keyboard — only the bottom sheet does, and it hides outright below
      // instead of fighting the keyboard for space.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: AppConfig.pickZoom,
                minZoom: AppConfig.minZoom,
                maxZoom: AppConfig.maxZoom,
                backgroundColor: AppColors.white,
                onPositionChanged: _onMapPositionChanged,
                // Haritaya dokunmak "formu biraktim" demek: klavye kapaniyor
                // ve panel yerine oturuyor. Aksi halde jaý/öý alanina yazip
                // haritayi kaydirmak isteyen biri once klavyeyi elle
                // kapatmak zorunda kaliyordu.
                onTap: (_, _) => _dismissKeyboard(),
                // Parmagini surukleyerek harita gezdirmek de ayni niyet.
                onPointerDown: (_, _) => _dismissKeyboard(),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConfig.mapTileUrl,
                  userAgentPackageName: AppConfig.mapUserAgent,
                  tileProvider: TileCacheService.tileProvider,
                  keepBuffer: 3,
                ),
              ],
            ),
          ),

          // Fixed pin — the map moves underneath it; its tip marks the point
          // that gets saved. It lifts off the map while being dragged and
          // drops back onto the exact same spot once the gesture settles,
          // so it reads as physically marking the point rather than just
          // sitting there. The ground shadow stays put and only breathes in
          // size, reinforcing which point is actually being marked.
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    // Sits just under the pin's own tip offset, so the
                    // shadow reads as ground contact right at the tip
                    // rather than floating below it.
                    padding: EdgeInsets.only(bottom: _pinHeight - 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: _dragging ? 10 : 14,
                      height: _dragging ? 4 : 5,
                      decoration: BoxDecoration(
                        color: AppColors.shadow.withValues(
                          alpha: _dragging ? 0.35 : 0.6,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    offset: Offset(0, _dragging ? -0.12 : 0),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      scale: _dragging ? 1.1 : 1.0,
                      child: Padding(
                        // Bottom padding must equal the pin's own painted
                        // height — that's what puts its tip, not its
                        // centre, exactly on the screen's true centre
                        // point.
                        padding: EdgeInsets.only(bottom: _pinHeight),
                        child: const DestinationPin(size: _pinSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MapButton(
                        icon: AppIcons.back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      // The only place left where the customer types free
                      // text — a search query, not the address itself. What
                      // ends up in the district field below always comes
                      // from picking a result here, dragging the pin, or a
                      // saved address, never straight from this box.
                      Expanded(
                        child: _AddressSearchField(
                          controller: _search,
                          focusNode: _searchFocus,
                          hint: s.addressSearchHint,
                          loading: _searching,
                          onSubmit: _runSearch,
                          onClear: _clearSearch,
                        ),
                      ),
                    ],
                  ),
                  // Gated on the query text, not focus: an on-screen
                  // keyboard's own "search" key can submit and drop focus
                  // in the same instant on some OEM keyboards, and results
                  // arrive a moment later — tying visibility to focus meant
                  // the panel could finish loading a real match and simply
                  // never show it.
                  if (_search.text.trim().isNotEmpty &&
                      (_searchResults.isNotEmpty ||
                          (_searchAttempted && !_searching))) ...[
                    const SizedBox(height: 8),
                    _AddressSearchResults(
                      results: _searchResults,
                      noResultsLabel: s.addressSearchNoResults,
                      alsoKnownAsLabel: s.alsoKnownAs,
                      onSelect: _applySearchResult,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Hidden while the search field has focus: `resizeToAvoidBottomInset`
          // is off above, so without this the keyboard would just bury the
          // sheet under itself instead of the two ever sharing the screen.
          // Sliding it fully off-screen also keeps it from being tapped
          // through the keyboard by accident.
          IgnorePointer(
            ignoring: _searchFocus.hasFocus,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              offset: _searchFocus.hasFocus ? const Offset(0, 1) : Offset.zero,
              child: Align(
                alignment: Alignment.bottomCenter,
                // Klavye kadar yukari it. `resizeToAvoidBottomInset` bilerek
                // kapali (yoksa harita da her klavyede yeniden boyutlanirdi),
                // bu yuzden panelin klavyenin ustune cikmasi burada saglaniyor.
                // Bosluk panelin *icine* konulunca ise panel ekranin altina
                // yapisik kaldigi icin buyuyen kisim klavyenin arkasinda
                // kaliyordu.
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Konumumu bul" dugmesi panelin hemen ustunde: sabit bir
                      // `bottom` degerine yaslandiginda panel uzadikca altinda
                      // kaliyordu. Ayni Column'da durunca panel ne kadar
                      // buyurse buyusun hep gorunur kaliyor.
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
                          child: _MapButton(
                            icon: AppIcons.myLocation,
                            busy: _findingLocation,
                            onTap: _useMyLocation,
                          ),
                        ),
                      ),
                      // Panel ekrandan tasmasin: klavye acikken ya da
                      // jaý/girelge/gat/öý bolumu genisken icerik ekrandan uzun
                      // olabiliyor. `Flexible` panele kalan yer kadarini verir,
                      // icindeki kaydirilabilir alan da gerisini halleder.
                      Flexible(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 20,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            // This sheet's height is fixed by the Container above it,
                            // while its content is not: a two-line district name, the
                            // conditional saved-address list, and translated RU/TK
                            // labels can all push the Column past that height by a
                            // hair — a fraction of a pixel today, more on a larger
                            // system font. Scrolling absorbs the overflow instead of
                            // clipping content or tripping the RenderFlex assertion.
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.pickOnMap,
                                    style: AppText.h2.copyWith(fontSize: 17),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.addressSearchOrPin,
                                    style: AppText.bodyMuted.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _ChosenAddressCard(
                                    label: s.districtLabel,
                                    address: _district.text,
                                    placeholder: s.addressSearchOrPin,
                                    loading: _locating,
                                  ),
                                  const SizedBox(height: 6),
                                  // Harita evi metre farkiyla bulur, kapiya kadar
                                  // goturmez: kurye asagidakiler olmadan binayi bulup
                                  // dogru daireyi calamiyor. Yine de cogu adreste bos
                                  // kaliyorlar, bu yuzden istege bagli bir bolum.
                                  DetailsToggle(
                                    expanded: _showDetails,
                                    label: _showDetails
                                        ? s.addressDetailsHide
                                        : s.addressDetailsShow,
                                    onTap: () => setState(
                                      () => _showDetails = !_showDetails,
                                    ),
                                  ),
                                  // AnimatedSize: acilip kapanirken panel zipla
                                  // yerine buyuyup kuculuyor.
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    alignment: Alignment.topCenter,
                                    child: _showDetails
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(height: 10),
                                              _Field(
                                                controller: _house,
                                                hint: s.houseLabel,
                                              ),
                                              const SizedBox(height: 10),
                                              // Ucu de kisa degerler — yan yana tek
                                              // satirda durunca form uzamiyor.
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _Field(
                                                      controller: _entrance,
                                                      hint: s.entranceLabel,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: _Field(
                                                      controller: _floor,
                                                      hint: s.floorLabel,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: _Field(
                                                      controller: _apartment,
                                                      hint: s.apartmentLabel,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        : const SizedBox(
                                            width: double.infinity,
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  _Field(
                                    controller: _note,
                                    hint: s.addressNoteHint,
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    label: s.save,
                                    onPressed: _canSave ? _save : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    // The app-wide input theme is a borderless white fill, built for fields
    // that sit on a tinted background — on this sheet's own white
    // background that reads as plain text, not a fillable box. This gets
    // its own visible outline plus a floating label, so a field the
    // customer has already filled in still shows which one it is.
    return TextField(
      controller: controller,
      style: AppText.body,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: AppText.body.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: AppText.body.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.8),
        ),
      ),
    );
  }
}

/// Shows the address the customer has landed on — from a search pick or a
/// dragged pin, never from typing here directly.
///
/// A real `TextField` looked exactly like every editable field around it
/// (same box, same floating label, a blinking cursor on tap even when
/// `readOnly` was set) even after typing into it was disabled, so a customer
/// naturally kept trying to type an address straight into it. This is
/// deliberately a plain, non-editable card instead — a pin glyph and a line
/// of text, nothing that invites a keyboard.
class _ChosenAddressCard extends StatelessWidget {
  const _ChosenAddressCard({
    required this.label,
    required this.address,
    required this.placeholder,
    this.loading = false,
  });

  final String label;
  final String address;
  final String placeholder;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.green,
                    ),
                  )
                : const HugeIcon(
                    icon: AppIcons.location,
                    color: AppColors.green,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.bodyMuted.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAddress ? address : placeholder,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasAddress
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final HugeIconData icon;
  final VoidCallback onTap;

  /// Swaps the glyph for a spinner while the work behind the button runs.
  /// The spinner is sized to the glyph so the button does not resize.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.green,
                    ),
                  )
                : HugeIcon(icon: icon, color: AppColors.green, size: 22),
          ),
        ),
      ),
    );
  }
}

/// The address search box floating over the map. Submitting a query here —
/// the enter key or the search glyph, never a live keystroke — is the only
/// way free text ever enters this screen; what it returns are real places,
/// picked from a list rather than typed into the address itself.
class _AddressSearchField extends StatelessWidget {
  const _AddressSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.loading,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool loading;
  final VoidCallback onSubmit;

  /// Clears the query and dismisses the keyboard — see
  /// [_AddressPickerScreenState._clearSearch].
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        style: AppText.body,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.green,
                    ),
                  )
                : InkWell(
                    onTap: onSubmit,
                    child: const HugeIcon(
                      icon: AppIcons.search,
                      color: AppColors.green,
                      size: 20,
                    ),
                  ),
          ),
          // Shown whenever there's something to undo — text to clear, or
          // just the keyboard itself while the field is focused empty —
          // so there's always a one-tap way out of search mode.
          suffixIcon: controller.text.isEmpty && !focusNode.hasFocus
              ? null
              : IconButton(
                  icon: const HugeIcon(
                    icon: AppIcons.cancel,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

/// Results of an explicit address search — real places from OpenStreetMap,
/// each one a candidate for the district field exactly the way a saved
/// address or a dropped pin already is.
class _AddressSearchResults extends StatelessWidget {
  const _AddressSearchResults({
    required this.results,
    required this.noResultsLabel,
    required this.alsoKnownAsLabel,
    required this.onSelect,
  });

  final List<GeocodingResult> results;
  final String noResultsLabel;
  final String alsoKnownAsLabel;
  final void Function(GeocodingResult) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text(noResultsLabel, style: AppText.bodyMuted),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 14, endIndent: 14),
              itemBuilder: (context, index) {
                final result = results[index];
                return InkWell(
                  // Runs before the field's own focus-out, same reasoning as
                  // the saved-address list — the tap must land before the
                  // panel it's inside disappears under the finger.
                  onTap: () => onSelect(result),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: HugeIcon(
                            icon: AppIcons.location,
                            color: AppColors.green,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.label,
                                style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (result.aliases.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '$alsoKnownAsLabel ${result.aliases.join(', ')}',
                                    style: AppText.bodyMuted.copyWith(
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
