import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat('#,##0');

/// Whole-rupee display used everywhere: `Rs 1,850`.
///
/// [signed] adds `+` or `−` in front for balances (`+Rs 200`, `−Rs 450`);
/// zero never gets a sign.
String formatRs(int amount, {bool signed = false}) {
  final text = 'Rs ${_grouped.format(amount.abs())}';
  if (!signed || amount == 0) return amount < 0 && !signed ? '−$text' : text;
  return '${amount > 0 ? '+' : '−'}$text';
}

/// Just the grouped number without "Rs": `1,850`.
String formatAmount(int amount) => _grouped.format(amount);
