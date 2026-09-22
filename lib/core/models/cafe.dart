/// One customer-facing brand in the catalogue.
///
/// A cafe is the first level a customer browses: several cafes are prepared
/// at the same operational location, so a cafe is *not* a delivery branch and
/// carries no pricing or availability authority of its own. It decides which
/// categories and products are shown, nothing more — an order may mix
/// products from several cafes and the backend still routes it to one branch.
class Cafe {
  const Cafe({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? description;

  /// A same-origin private media path, resolved exactly like product and
  /// category images.
  final String? imageUrl;

  /// The order the backend wants the cafes shown in; ties break by name.
  final int sortOrder;
}
