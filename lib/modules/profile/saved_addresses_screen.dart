import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/delivery_address.dart';
import '../../core/models/saved_address.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../checkout/address_picker_screen.dart';
import '../checkout/address_provider.dart';

/// A full page for the customer's saved addresses — replaces the old bottom
/// sheet. There's a real list to browse here (label, district, current-vs-
/// not, a destructive delete), which a sheet compresses into cramped
/// `ListTile`s; a page gives each address room to read as its own card.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().load();
    });
  }

  Future<void> _remove(SavedAddress item, AppStrings s) async {
    final confirmed = await _RemoveConfirmDialog.show(
      context,
      title: s.removeAddressConfirmTitle,
      message: s.removeAddressConfirmMessage,
      confirmLabel: s.removeAddressLabel,
      cancelLabel: s.cancel,
    );
    if (!confirmed || !mounted) return;
    await context.read<AddressProvider>().removeSaved(item);
  }

  Future<void> _addAddress() async {
    // AddressPickerScreen already does the map-pin-plus-district/house form
    // — reused as-is rather than building a second entry form for the same
    // shape of data.
    final result = await Navigator.of(context).push<DeliveryAddress>(
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (result == null || !mounted) return;
    await context.read<AddressProvider>().addNew(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final addresses = context.watch<AddressProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(s.savedAddresses),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: addresses.loading
          ? const Center(child: CircularProgressIndicator())
          : addresses.saved.isEmpty
          ? _EmptyState(
              title: s.savedAddressesEmpty,
              hint: s.savedAddressesEmptyHint,
              buttonLabel: s.addAddress,
              onAdd: _addAddress,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: addresses.saved.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = addresses.saved[index];
                return _AddressCard(
                  item: item,
                  strings: s,
                  onTap: () => addresses.selectSaved(item),
                  onRemove: () => _remove(item, s),
                );
              },
            ),
      floatingActionButton: addresses.saved.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addAddress,
              backgroundColor: AppColors.orange,
              icon: const HugeIcon(
                icon: AppIcons.add,
                color: AppColors.white,
                size: 20,
              ),
              label: Text(
                s.addAddress,
                style: AppText.button.copyWith(
                  color: AppColors.white,
                  fontSize: 15,
                ),
              ),
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.item,
    required this.strings,
    required this.onTap,
    required this.onRemove,
  });

  final SavedAddress item;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// The label is free text from the server — matching it against "Дом" /
  /// "Öý" style values picks a friendlier icon than the generic pin when it
  /// obviously means home or work, without needing the server to send a
  /// dedicated type field.
  HugeIconData get _icon {
    final label = item.label?.toLowerCase() ?? '';
    if (label.contains(strings.addressHome.toLowerCase())) {
      return AppIcons.home;
    }
    if (label.contains(strings.addressWork.toLowerCase())) {
      return AppIcons.package;
    }
    return AppIcons.location;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isActive
              ? AppColors.green.withValues(alpha: 0.5)
              : AppColors.green.withValues(alpha: 0.12),
          width: item.isActive ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: HugeIcon(
                    icon: _icon,
                    color: AppColors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label ?? item.address.district,
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isActive) ...[
                            const SizedBox(width: 8),
                            _ActiveBadge(label: strings.activeAddressLabel),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.address.district,
                        style: AppText.bodyMuted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: HugeIcon(
                      icon: AppIcons.delete,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: AppIcons.check, color: AppColors.white, size: 11),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppText.chip.copyWith(color: AppColors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.hint,
    required this.buttonLabel,
    required this.onAdd,
  });

  final String title;
  final String hint;
  final String buttonLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: AppIcons.location,
                color: AppColors.textMuted,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(hint, style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: buttonLabel,
                icon: AppIcons.add,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same visual language as the sign-out/delete-account confirmations on the
/// profile screen — a destructive action gets a deliberate second tap, not
/// a single "are you sure" OK.
class _RemoveConfirmDialog extends StatelessWidget {
  const _RemoveConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: AppIcons.delete,
                color: AppColors.red,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: cancelLabel,
                    height: 48,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    height: 48,
                    color: AppColors.red,
                    textColor: AppColors.white,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
