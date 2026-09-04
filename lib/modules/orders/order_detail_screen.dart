import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/models/order_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/delivery_map.dart';
import '../../core/widgets/dish_thumbnail.dart';
import '../../core/widgets/order_status_chip.dart';
import 'order_provider.dart';
import 'widgets/courier_contact_row.dart';
import 'widgets/order_rating_row.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/status_timeline.dart';

/// What a card tap opens first: the order itself — items, price breakdown,
/// address, progress, and a small static map of the delivery point that
/// expands to a bigger one on tap.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _cancelling = false;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  CustomerOrder? _find(OrderProvider provider) {
    for (final order in provider.orders) {
      if (order.id == widget.orderId) return order;
    }
    return null;
  }

  Future<void> _cancelOrder(CustomerOrder order, AppStrings s) async {
    final reason = await _CancelOrderDialog.show(context, strings: s);
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<OrderProvider>().cancelOrder(order, reason: reason);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.orderCancelledMessage)));
    } catch (error) {
      if (!mounted) return;
      final tooLate = error is StateError && error.message == 'order_too_late';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tooLate ? s.orderCancelTooLateMessage : s.orderCancelFailedMessage,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final order = _find(context.watch<OrderProvider>());

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = order.status;

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(
        title: Text(s.orderNumber(order.number)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _Card(
            child: Row(
              children: [
                OrderStatusBadge(status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.orderNumber(order.number), style: AppText.h2.copyWith(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(Fmt.date(order.placedAt), style: AppText.bodyMuted),
                    ],
                  ),
                ),
                OrderStatusChip(status: status, strings: s),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (status.isOpen) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusTimeline(order: order, strings: s),
                  if (status == OrderStatus.onTheWay && order.courierName != null) ...[const Divider(height: 28), CourierContactRow(order: order, strings: s, onCall: _call)],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (order.isCancellable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppButton(
                  label: s.cancelOrderAction,
                  icon: AppIcons.cancel,
                  color: AppColors.redSoft,
                  textColor: AppColors.red,
                  busy: _cancelling,
                  onPressed: () => _cancelOrder(order, s),
                ),
              ),
          ],
          if (status == OrderStatus.delivered) ...[
            _Card(
              child: OrderRatingRow(order: order, strings: s),
            ),
            const SizedBox(height: 12),
          ],
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SectionIcon(icon: AppIcons.package, color: AppColors.orange),
                    const SizedBox(width: 12),
                    Text(s.orderItemsTitle, style: AppText.label),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(20)),
                      child: Text(s.dishesCount(order.itemCount), style: AppText.chip.copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final item in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: DishThumbnail(dish: item.dish, borderRadius: BorderRadius.circular(12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text('${item.quantity} × ${Fmt.money(item.unitPrice)}', style: AppText.bodyMuted),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(Fmt.money(item.lineTotal), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (item != order.items.last) const Padding(padding: EdgeInsets.only(bottom: 12), child: Divider(height: 1)),
                ],
                const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider()),
                _TotalsRow(label: s.dishesTotal, value: Fmt.money(order.subtotal)),
                const SizedBox(height: 8),
                _TotalsRow(label: s.deliveryFeeLabel, value: Fmt.money(order.deliveryFee)),
                if (order.discount > 0) ...[const SizedBox(height: 8), _TotalsRow(label: s.discountLabel, value: '-${Fmt.money(order.discount)}', valueColor: AppColors.orange)],
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _TotalsRow(label: s.grandTotal, value: Fmt.money(order.total), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.deliveryAddressTitle, style: AppText.label),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HugeIcon(icon: AppIcons.location, color: AppColors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.address.fullLine(districtLabel: s.districtLabel, houseLabel: s.houseLabel),
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Builder(
                            builder: (context) {
                              final detail = order.address.detailLine(entranceLabel: s.entranceLabel, floorLabel: s.floorLabel, apartmentLabel: s.apartmentLabel);
                              if (detail.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(detail, style: AppText.bodyMuted),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MapPreview(destinationPoint: order.address.point, branchPoint: order.branchPoint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted circle carrying a section's glyph — same badge language as
/// checkout, so the item list reads consistently wherever it appears.
class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color});

  final HugeIconData icon;
  final Color color;
  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Center(
        child: HugeIcon(icon: icon, color: color, size: _size * 0.5),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// A small, non-interactive preview of the delivery point — tapping it (or
/// its own expand button) opens the same map full-size in a bottom sheet.
/// Deliberately just the map: this is "where did it go", not a second copy
/// of the live-tracking screen's status and timeline.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.destinationPoint, this.branchPoint});

  final LatLng destinationPoint;
  final LatLng? branchPoint;

  void _expand(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapSheet(destinationPoint: destinationPoint, branchPoint: branchPoint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: DeliveryMap(destinationPoint: destinationPoint, branchPoint: branchPoint, interactive: false),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: () => _expand(context)),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: AppColors.white,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: AppColors.shadow,
                child: InkWell(
                  onTap: () => _expand(context),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: HugeIcon(icon: AppIcons.expand, color: AppColors.green, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSheet extends StatelessWidget {
  const _MapSheet({required this.destinationPoint, this.branchPoint});

  final LatLng destinationPoint;
  final LatLng? branchPoint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DeliveryMap(destinationPoint: destinationPoint, branchPoint: branchPoint),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 6)],
                      ),
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

/// Cancellation's own confirmation — a destructive action, so it gets the
/// same deliberate second tap as sign-out/delete-account, plus a reason
/// field the server requires and staff later see in the order history.
class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({required this.strings});

  final AppStrings strings;

  static Future<String?> show(
    BuildContext context, {
    required AppStrings strings,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _CancelOrderDialog(strings: strings),
    );
  }

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorText = widget.strings.cancelOrderReasonRequired);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  static OutlineInputBorder _reasonBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.redSoft,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: AppIcons.cancel, color: AppColors.red, size: 26),
              ),
            ),
            const SizedBox(height: 18),
            Text(s.cancelOrderConfirmTitle, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.cancelOrderConfirmMessage, style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            TextField(
              controller: _reasonController,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              // The global input theme is borderless on a white fill, which
              // vanishes against this dialog's white card — so this field
              // spells out its own visible outline for every state.
              decoration: InputDecoration(
                hintText: s.cancelOrderReasonHint,
                errorText: _errorText,
                filled: true,
                fillColor: AppColors.neutralGrey,
                border: _reasonBorder(AppColors.divider),
                enabledBorder: _reasonBorder(AppColors.divider),
                focusedBorder: _reasonBorder(AppColors.green, width: 1.6),
                errorBorder: _reasonBorder(AppColors.red),
                focusedErrorBorder: _reasonBorder(AppColors.red, width: 1.6),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: s.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: s.cancelOrderAction,
                    color: AppColors.red,
                    onPressed: _confirm,
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

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? AppText.h2.copyWith(fontSize: 17) : AppText.body;
    return Row(
      children: [
        Expanded(child: Text(label, style: bold ? style : AppText.bodyMuted)),
        Text(value, style: style.copyWith(color: valueColor)),
      ],
    );
  }
}
