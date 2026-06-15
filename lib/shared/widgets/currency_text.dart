import 'package:flutter/material.dart';
import 'package:safespend/core/utils/currency_formatter.dart';

/// A standardized text widget that formats a [double] as Japanese Yen without
/// decimals (e.g., ¥200,000). Uses bold weight by default for monetary amounts.
class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool bold;

  const CurrencyText(
    this.amount, {
    super.key,
    this.style,
    this.textAlign,
    this.bold = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        bold ? Theme.of(context).textTheme.headlineMedium : null;
    return Text(
      formatCurrency(amount),
      style: (defaultStyle ?? const TextStyle()).merge(style),
      textAlign: textAlign,
    );
  }
}

/// Shorthand: CurrencyText(amount). Use this for inline use where the CurrencyText
/// widget is too verbose.
Widget currencyText(double amount, {TextStyle? style, bool bold = true}) {
  return CurrencyText(amount, style: style, bold: bold);
}