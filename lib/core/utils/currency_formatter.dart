import 'package:intl/intl.dart';

/// Formats a [double] as Japanese Yen without decimals.
/// e.g., 200000 -> "¥200,000"
String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}