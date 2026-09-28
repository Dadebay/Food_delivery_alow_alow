/// Reads a number that may arrive as a number or as a string.
///
/// Money and rates are SQL decimals on the server, and a decimal is
/// serialised as a *string* — `"140"`, not `140` — so no digits are lost on
/// the way through JSON. A plain `as num` cast on those throws
/// `type 'String' is not a subtype of type 'num?'`, and because every
/// repository here turns a parse failure into "no answer", the customer was
/// shown a fallback price while the server had answered correctly.
///
/// Returns null for anything that is not a number and not a string holding
/// one — a missing field and a malformed one are both "no value".
double? readDouble(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s.trim()),
  _ => null,
};

/// The whole-number form of [readDouble]. Accepts `"12"` and `12.0` alike;
/// a fractional string is truncated the same way `num.toInt()` would.
int? readInt(Object? value) => readDouble(value)?.toInt();
