/// Whether the kitchen is taking orders right now — `GET /ordering-hours`.
///
/// [isOpen] is the server's own verdict and the only thing the app acts on.
/// The window can cross midnight and the phone's clock can be wrong or in
/// another timezone; comparing [opensAt]/[closesAt] against local time here
/// would get both cases wrong. Those two are for telling the customer when
/// to come back, nothing else.
class OrderingHours {
  const OrderingHours({
    required this.isOpen,
    required this.enabled,
    this.opensAt,
    this.closesAt,
    this.timezone,
    this.serverTime,
  });

  final bool isOpen;

  /// False = the restaurant does not restrict hours at all, so orders are
  /// always accepted and the window should not be shown.
  final bool enabled;

  final String? opensAt;
  final String? closesAt;
  final String? timezone;
  final DateTime? serverTime;

  /// True only when the server says it is both enforcing hours and shut.
  bool get blocksOrdering => enabled && !isOpen;

  bool get hasWindow => opensAt != null && closesAt != null;

  factory OrderingHours.fromJson(Map<String, dynamic> json) => OrderingHours(
    // A server that answers without saying otherwise is open: this endpoint
    // gates the order button, and a missing field must not lock a working
    // shop out of taking orders.
    isOpen: json['isOpen'] as bool? ?? true,
    enabled: json['enabled'] as bool? ?? false,
    opensAt: json['opensAt'] as String?,
    closesAt: json['closesAt'] as String?,
    timezone: json['timezone'] as String?,
    serverTime: DateTime.tryParse(json['serverTime'] as String? ?? ''),
  );

  /// What the app assumes when the endpoint does not exist on this server.
  static const OrderingHours unrestricted = OrderingHours(
    isOpen: true,
    enabled: false,
  );
}
