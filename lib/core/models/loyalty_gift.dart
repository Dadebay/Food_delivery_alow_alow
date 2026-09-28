/// One item in the gift shop — mirrors an entry of `GET /loyalty/gifts`.
///
/// A gift is never bought on its own: it rides along with an order that has
/// food in it, and it is paid for in points rather than manat. Nothing here
/// is ever added to the cart's money total.
class LoyaltyGift {
  const LoyaltyGift({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsCost,
    this.imageUrl,
    this.stock,
  });

  final String id;
  final String name;
  final String description;

  /// What it costs in points. The server does the spending; this is only
  /// what the customer is shown before they commit.
  final int pointsCost;

  /// Absolute by the time it reaches here — the API sends a same-origin
  /// `/api/v1/media/<uuid>.webp` path, resolved against the API base in the
  /// repository, exactly as dish and category photos are.
  final String? imageUrl;

  /// How many are left, or `null` for "no limit" — which is a real state the
  /// API uses, not a missing value. A gift with `stock: 0` is filtered out
  /// server-side and should not arrive here at all.
  final int? stock;

  bool get isUnlimited => stock == null;
  bool get isSoldOut => stock != null && stock! <= 0;

  factory LoyaltyGift.fromJson(
    Map<String, dynamic> json, {
    String? Function(Object?)? resolveImage,
  }) => LoyaltyGift(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
    imageUrl: resolveImage == null
        ? json['imageUrl'] as String?
        : resolveImage(json['imageUrl']),
    stock: (json['stock'] as num?)?.toInt(),
  );
}
