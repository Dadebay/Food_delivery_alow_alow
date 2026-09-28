/// What a point entry did to the balance.
///
/// [unknown] exists because the server owns this vocabulary: a kind added
/// later must render as a plain row rather than crash a screen the customer
/// opened to check their points.
enum LoyaltyEntryKind { earn, redeem, refund, reverseEarn, unknown }

/// One line of the customer's point history.
class LoyaltyEntry {
  const LoyaltyEntry({
    required this.kind,
    required this.points,
    required this.createdAt,
  });

  final LoyaltyEntryKind kind;

  /// Signed: positive for what was added, negative for what was taken. Shown
  /// as it arrives — the app never re-derives the sign from [kind].
  final int points;

  final DateTime? createdAt;

  factory LoyaltyEntry.fromJson(Map<String, dynamic> json) => LoyaltyEntry(
    kind: switch ((json['kind'] as String? ?? '').toUpperCase()) {
      'EARN' => LoyaltyEntryKind.earn,
      'REDEEM' => LoyaltyEntryKind.redeem,
      'REFUND' => LoyaltyEntryKind.refund,
      'REVERSE_EARN' => LoyaltyEntryKind.reverseEarn,
      _ => LoyaltyEntryKind.unknown,
    },
    points: (json['points'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

/// The customer's point balance and recent history — `GET /loyalty/me`.
class LoyaltyAccount {
  const LoyaltyAccount({required this.pointsBalance, this.entries = const []});

  /// The server's own number. Never the sum of [entries]: the history is the
  /// last few operations, not the whole ledger, and adding it up would
  /// disagree with the balance the server will actually charge against.
  ///
  /// It can be negative — cancelling an order after its points were already
  /// earned takes them back — and is displayed as it arrives.
  final int pointsBalance;

  final List<LoyaltyEntry> entries;

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) => LoyaltyAccount(
    pointsBalance: (json['pointsBalance'] as num?)?.toInt() ?? 0,
    entries: (json['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LoyaltyEntry.fromJson)
        .toList(),
  );
}
