import 'package:flutter/material.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/core/utils/date_extensions.dart';

/// A ListTile wrapper used to display transaction history.
///
/// Props: Icon, Title, Date (formatted "MMM dd, yyyy"), Amount, Note.
class TransactionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime date;
  final double amount;
  final String? note;

  const TransactionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.date,
    required this.amount,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.toDisplayFormat(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (note != null && note!.isNotEmpty)
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          formatCurrency(amount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}