import 'package:flutter/material.dart';
import 'package:safespend/core/theme/app_theme.dart';

/// A small, rounded container for fixed bills showing "Paid" (Green) or
/// "Pending" (Yellow).
class StatusPill extends StatelessWidget {
  final bool isPaid;

  const StatusPill({
    super.key,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isPaid
        ? AppTheme.green.withAlpha(30)
        : AppTheme.yellow.withAlpha(40);
    final Color fgColor = isPaid ? AppTheme.green : AppTheme.orange;
    final String label = isPaid ? 'Paid' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}