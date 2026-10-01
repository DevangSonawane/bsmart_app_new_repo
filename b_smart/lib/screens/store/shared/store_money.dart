/// Money formatting for the store surfaces.
///
/// Amounts were rendered with a bare `toStringAsFixed`, which produced
/// `₹1000` instead of `₹1,000`. Every store price display goes through here so
/// the grouping is consistent.
///
/// Whole amounts drop the decimals (`1,000`); fractional amounts keep two
/// (`1,000.50`), matching the previous behaviour site by site.
///
/// Do NOT use this for text-field prefills. A comma is not valid input for
/// `double.tryParse`, so an editable price field must stay unformatted.
library;

/// Inserts thousands separators into a run of digits: `1234567` -> `1,234,567`.
String groupThousands(String digits) {
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats [amount] with thousands separators.
///
/// [decimals] of `null` keeps two decimals only when the amount is fractional,
/// which is the common "₹999" / "₹999.50" case.
String formatStoreAmount(
  double amount, {
  int? decimals,
  String prefix = '',
}) {
  final places = decimals ??
      (amount == amount.roundToDouble() && amount.isFinite ? 0 : 2);
  final fixed = amount.toStringAsFixed(places);
  final negative = fixed.startsWith('-');
  final body = negative ? fixed.substring(1) : fixed;
  final dot = body.indexOf('.');
  final whole = dot == -1 ? body : body.substring(0, dot);
  final rest = dot == -1 ? '' : body.substring(dot);
  // The sign goes outside the prefix so a negative reads `-₹1,200`, not
  // `₹-1,200`.
  return '${negative ? '-' : ''}$prefix${groupThousands(whole)}$rest';
}

String _trimFixed(double value, int decimals) {
  var text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '');
}

/// Formats large display-only amounts with compact suffixes:
/// `₹1.2k`, `₹3.4m`, `₹5.6b`.
String formatCompactStoreMoney(double amount, {int decimals = 1}) {
  if (!amount.isFinite) return formatStoreMoney(0);
  final negative = amount < 0;
  final absolute = amount.abs();
  final (divisor, suffix) = switch (absolute) {
    >= 1000000000 => (1000000000.0, 'b'),
    >= 1000000 => (1000000.0, 'm'),
    >= 1000 => (1000.0, 'k'),
    _ => (1.0, ''),
  };
  if (suffix.isEmpty) return formatStoreMoney(amount);
  final compact = _trimFixed(absolute / divisor, decimals);
  return '₹${negative ? '-' : ''}$compact$suffix';
}

/// `formatStoreAmount` with the rupee sign, e.g. `₹1,000`.
String formatStoreMoney(double amount, {int? decimals}) =>
    formatStoreAmount(amount, decimals: decimals, prefix: '₹');
