part of 'checkout_screen.dart';

/// Shared white, rounded, softly-shadowed surface every checkout section
/// sits on — the one visual unit the whole screen is built from.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small tinted circle carrying a section's glyph — the same soft-badge
/// language repeated once per card so the eye can jump straight to the part
/// of checkout it's looking for (where / what / how much).
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color, this.size = 34});

  final HugeIconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: HugeIcon(icon: icon, color: color, size: size * 0.5),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.strings,
    required this.onTap,
  });

  final DeliveryAddress? address;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionIcon(icon: AppIcons.location, color: AppColors.onBrand),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.deliveryAddressLabel, style: AppText.label),
                      const SizedBox(height: 6),
                      if (address == null)
                        Text(
                          strings.pickOnMap,
                          style: AppText.h2.copyWith(fontSize: 16),
                        )
                      else ...[
                        Text(
                          address!.fullLine(
                            districtLabel: strings.districtLabel,
                            houseLabel: strings.houseLabel,
                          ),
                          style: AppText.h2.copyWith(fontSize: 16),
                        ),
                        if (address!.entrance != null ||
                            address!.floor != null ||
                            address!.apartment != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            address!.detailLine(
                              entranceLabel: strings.entranceLabel,
                              floorLabel: strings.floorLabel,
                              apartmentLabel: strings.apartmentLabel,
                            ),
                            style: AppText.bodyMuted,
                          ),
                        ],
                        if (address!.note != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            address!.note!,
                            style: AppText.bodyMuted.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (address != null)
                      Text(
                        strings.changeAddress,
                        style: AppText.chip.copyWith(
                          color: AppColors.onBrand,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 2),
                    const HugeIcon(
                      icon: AppIcons.chevronRight,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.cart, required this.strings});

  final CartProvider cart;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(icon: AppIcons.package, color: AppColors.orange),
              const SizedBox(width: 12),
              Text(strings.itemsSummaryLabel, style: AppText.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  strings.dishesCount(cart.itemCount),
                  style: AppText.chip.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in cart.items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: DishThumbnail(
                      dish: item.dish,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} × ${Fmt.money(item.unitPrice)}',
                          style: AppText.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.money(item.lineTotal),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (item != cart.items.last)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

/// Free-text note for the whole order — sent as `customerNote`, shown in
/// the admin and printed on the main and kitchen receipts (see
/// `OrderRepository.place`). Always visible rather than collapsed like the
/// promo field: unlike a code, there's nothing to "apply" here, so a plain
/// multi-line box is the whole interaction. The outline brightens to green
/// on focus — the same feedback the cancel-order reason field uses — so a
/// tap reads as "writing" rather than just a static text box.
class _OrderCommentField extends StatefulWidget {
  const _OrderCommentField({required this.controller, required this.strings});

  final TextEditingController controller;
  final AppStrings strings;

  @override
  State<_OrderCommentField> createState() => _OrderCommentFieldState();
}

class _OrderCommentFieldState extends State<_OrderCommentField> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);
  bool _focused = false;
  OverlayEntry? _doneBar;

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _showDoneBar();
    } else {
      _removeDoneBar();
    }
  }

  /// A multiline field gets a newline key instead of "done", so iOS offers no
  /// way out of the keyboard at all. This is the accessory bar native apps put
  /// there: pinned directly above the keyboard, impossible to miss.
  void _showDoneBar() {
    if (_doneBar != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _doneBar = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(overlayContext).viewInsets.bottom,
        child: Material(
          color: AppColors.neutralGrey,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _focusNode.unfocus,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onBrand,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(
                      widget.strings.keyboardDoneAction,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_doneBar!);
  }

  void _removeDoneBar() {
    _doneBar?.remove();
    _doneBar = null;
  }

  @override
  void dispose() {
    _removeDoneBar();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  static OutlineInputBorder _border(Color color, {double width = 1.3}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(
                icon: AppIcons.note,
                color: AppColors.onBrand,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.orderCommentLabel,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              // Only shown while writing — a quiet nudge that this is
              // optional, without permanently taking up header space.
              AnimatedOpacity(
                opacity: _focused ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  s.orderCommentOptional,
                  style: AppText.bodyMuted.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.body,
            cursorColor: AppColors.brand,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _focused ? AppColors.white : AppColors.neutralGrey,
              contentPadding: const EdgeInsets.all(14),
              border: _border(AppColors.divider, width: 1.1),
              enabledBorder: _border(AppColors.divider, width: 1.1),
              focusedBorder: _border(AppColors.brand),
              hintText: s.orderCommentHint,
              hintStyle: AppText.bodyMuted,
              counterStyle: AppText.bodyMuted.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
