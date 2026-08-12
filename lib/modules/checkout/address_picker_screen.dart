import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/saved_address.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/tile_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/car_marker.dart';
import 'address_provider.dart';

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

  /// What geocoding itself last wrote into the district field — as long as
  /// the field still holds exactly this, overwriting it on the next pin
  /// move is safe. The moment it doesn't match, the customer has typed
  /// something of their own, and geocoding stops touching the field.
  String? _lastGeocodedText;

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

  // Shows the saved-address shortcuts under the district field the moment
  // it's focused — no separate "pick from saved" step, and typing a fresh
  // address still works exactly as before.
  final FocusNode _districtFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _geocoder = context.read<GeocodingService>();
    for (final c in [_district, _house, _entrance, _floor, _apartment, _note]) {
      c.addListener(_onFieldChanged);
    }
    _districtFocus.addListener(_onFieldChanged);
    if (widget.initial == null) {
      _useMyLocation();
    } else {
      // Editing an already-saved address — it already has a district the
      // customer chose, so geocoding stays quiet until they actually move
      // the pin themselves.
      _lastGeocodedText = _district.text;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().load();
    });
  }

  @override
  void dispose() {
    for (final c in [_district, _house, _entrance, _floor, _apartment, _note]) {
      c.dispose();
    }
    _districtFocus.dispose();
    _dragEndTimer?.cancel();
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
      // Only overwrite what geocoding itself put there last time — never a
      // district the customer typed themselves.
      final safeToOverwrite =
          _district.text.isEmpty || _district.text == _lastGeocodedText;
      if (result != null && safeToOverwrite) {
        _district.text = result;
        _lastGeocodedText = result;
      }
    });
  }

  void _applySaved(SavedAddress item) {
    _district.text = item.address.district;
    if (item.address.house.isNotEmpty) _house.text = item.address.house;
    _entrance.text = item.address.entrance ?? '';
    _floor.text = item.address.floor ?? '';
    _apartment.text = item.address.apartment ?? '';
    _center = item.address.point;
    _map.move(_center, AppConfig.pickZoom);
    _districtFocus.unfocus();
  }

  bool get _canSave => _district.text.trim().isNotEmpty;

  Future<void> _useMyLocation() async {
    final point = await context.read<LocationService>().fetch();
    if (point != null && mounted) {
      setState(() => _center = point);
      // A programmatic move like this never reaches `_onMapPositionChanged`
      // with `hasGesture: true` — flutter_map only sets that flag for an
      // actual finger drag — so geocoding has to be kicked off by hand here,
      // or the pin's very first, GPS-picked position never gets looked up.
      _map.move(point, AppConfig.pickZoom);
      _reverseGeocode(point);
    }
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
    final saved = context.watch<AddressProvider>().saved;

    return Scaffold(
      backgroundColor: AppColors.white,
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
              child: _MapButton(
                icon: AppIcons.back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 280,
            child: _MapButton(icon: AppIcons.myLocation, onTap: _useMyLocation),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.pickOnMap, style: AppText.h2.copyWith(fontSize: 17)),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _district,
                      hint: s.districtLabel,
                      focusNode: _districtFocus,
                      keepFocusOnOutsideTap: true,
                      loading: _locating,
                      maxLines: 2,
                    ),
                    if (_districtFocus.hasFocus && saved.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SavedAddressSuggestions(
                        items: saved,
                        onSelect: _applySaved,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _Field(controller: _note, hint: s.addressNoteHint),
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
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.keepFocusOnOutsideTap = false,
    this.loading = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int maxLines;

  /// The district field sets this — otherwise the default tap-outside
  /// behaviour unfocuses it the instant a finger lands on the suggestions
  /// list below, tearing that list out of the widget tree before its own
  /// tap can land. [_applySaved] unfocuses explicitly once a pick lands.
  final bool keepFocusOnOutsideTap;

  /// True while reverse geocoding is filling this field in — a small spinner
  /// in place of a suffix icon so the customer sees the pin drop actually
  /// did something, without blocking them from typing over it immediately.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // The app-wide input theme is a borderless white fill, built for fields
    // that sit on a tinted background — on this sheet's own white
    // background that reads as plain text, not a fillable box. These get
    // their own visible outline plus a floating label, so a field the
    // customer has already filled in still shows which one it is.
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onTapOutside: keepFocusOnOutsideTap ? (_) {} : null,
      maxLines: maxLines,
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
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.green,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// The customer's saved addresses, offered right under the district field
/// the moment it's focused — a shortcut past retyping a mikrorayon they've
/// already entered once, not a replacement for typing a new one.
class _SavedAddressSuggestions extends StatelessWidget {
  const _SavedAddressSuggestions({required this.items, required this.onSelect});

  final List<SavedAddress> items;
  final void Function(SavedAddress) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 14, endIndent: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            // Runs before the field's own focus-out fires, so the tap
            // isn't lost to the list disappearing under the finger.
            onTap: () => onSelect(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: AppIcons.location,
                    color: AppColors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label ?? item.address.district,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.label != null)
                          Text(
                            item.address.district,
                            style: AppText.bodyMuted.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final HugeIconData icon;
  final VoidCallback onTap;

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
          child: HugeIcon(icon: icon, color: AppColors.green, size: 22),
        ),
      ),
    );
  }
}
