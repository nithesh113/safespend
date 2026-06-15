import 'package:flutter/material.dart';
import 'package:safespend/core/theme/app_theme.dart';
import 'package:safespend/core/utils/currency_formatter.dart';

/// A card displaying a savings goal, complete with a LinearProgressIndicator
/// showing the completion percentage.
class ProgressJarCard extends StatelessWidget {
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final VoidCallback? onTap;

  const ProgressJarCard({
    super.key,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.onTap,
  });

  double get progress {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? AppTheme.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatCurrency(currentAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.green,
                        ),
                      ),
                      Text(
                        'of ${formatCurrency(targetAmount)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percent%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Target date (if set)
              if (targetDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Goal: $targetDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}