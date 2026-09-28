import 'dart:math';

/// A random (version 4) UUID, as the order endpoint's `idempotencyKey`.
///
/// Written out rather than pulled from a package: this is the only place the
/// app needs a UUID, and the format is twelve lines of RFC 4122 §4.4 —
/// sixteen random bytes with the version and variant bits pinned.
///
/// [Random.secure] rather than the default generator: two customers ordering
/// at the same moment must not be able to produce the same key, and the
/// default is seeded predictably enough that it is not worth the argument.
String uuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Version 4 in the high nibble of byte 6, and the RFC's `10x` variant in
  // the top bits of byte 8. Without these it is a random string that merely
  // looks like a UUID, and a strict server is entitled to reject it.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
