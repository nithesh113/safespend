import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/features/activity/providers/activity_provider.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';
import 'package:safespend/shared/models/transaction.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActivityProvider()..load(),
      child: const _ActivityView(),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView();

  Future<void> _refresh(BuildContext context) async {
    await context.read<ActivityProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ActivityProvider, AppSettingsProvider, SavingsProvider>(
      builder: (context, activity, settings, savings, _) {
        if (activity.loading && activity.transactions.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (activity.errorMessage != null && activity.transactions.isEmpty) {
          return Scaffold(body: _errorState(context, activity.errorMessage!));
        }
        final remaining = math.max(
          0,
          settings.monthlyIncome -
              activity.totalSpent -
              activity.savingsContributions,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Reports',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: () => context.go('/transactions'),
                tooltip: 'All transactions',
                icon: const Icon(Icons.list_alt_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _periodHeader(context, activity),
                const SizedBox(height: 12),
                _summaryCard(
                  context,
                  activity,
                  settings.monthlyIncome,
                  remaining.toDouble(),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Income vs spending'),
                const SizedBox(height: 8),
                _comparisonCard(context, activity, settings.monthlyIncome),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Spending by category'),
                const SizedBox(height: 8),
                _categoryCard(context, activity),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Bills this month'),
                const SizedBox(height: 8),
                _billSummaryCard(context, activity, settings),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Savings progress'),
                const SizedBox(height: 8),
                _savingsProgressCard(context, savings),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Daily spending'),
                const SizedBox(height: 8),
                _dailyCard(context, activity),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle(context, 'This month'),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (activity.transactions.isEmpty)
                  _emptyCard(context)
                else
                  ...activity.transactions
                      .take(8)
                      .map(
                        (transaction) => _transactionRow(context, transaction),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _periodHeader(BuildContext context, ActivityProvider activity) => Row(
    children: [
      Icon(
        Icons.calendar_month_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          activity.monthLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        onPressed: () => activity.load(
          month: DateTime(
            activity.selectedMonth.year,
            activity.selectedMonth.month - 1,
          ),
        ),
        tooltip: 'Previous month',
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        onPressed: activity.isCurrentMonth
            ? null
            : () => activity.load(
                month: DateTime(
                  activity.selectedMonth.year,
                  activity.selectedMonth.month + 1,
                ),
              ),
        tooltip: 'Next month',
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _summaryCard(
    BuildContext context,
    ActivityProvider activity,
    double income,
    double safeToSpend,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9E0FF), Color(0xFFC7B4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric('Income', income, Colors.black87),
              _metric('Spent', activity.totalSpent, theme.colorScheme.error),
              _metric(
                'Saved',
                activity.savingsContributions,
                const Color(0xFF2E7D32),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safe to spend',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                formatCurrency(safeToSpend),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, double amount, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _comparisonCard(
    BuildContext context,
    ActivityProvider activity,
    double income,
  ) {
    final spent = activity.totalSpent;
    final saved = activity.savingsContributions;
    final maxValue = math.max(1.0, math.max(income, math.max(spent, saved)));
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 18, 10),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.15,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxValue / 2,
                      getTitlesWidget: (value, meta) => Text(
                        _compactAmount(value),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Income', 'Spent', 'Saved'];
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            labels[index],
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _barGroup(0, income, const Color(0xFF6C3CEB)),
                  _barGroup(1, spent, theme.colorScheme.error),
                  _barGroup(2, saved, const Color(0xFF2E7D32)),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legend('Income', const Color(0xFF6C3CEB)),
              _legend('Spent', theme.colorScheme.error),
              _legend('Saved', const Color(0xFF2E7D32)),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double value, Color color) =>
      BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 32,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      );

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  String _compactAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }

  Widget _billSummaryCard(
    BuildContext context,
    ActivityProvider activity,
    AppSettingsProvider settings,
  ) {
    final bills = settings.fixedBillCategories
        .where((bill) => bill.enabled && (bill.expectedMonthlyAmount ?? 0) > 0)
        .toList();
    final planned = bills.fold<double>(
      0,
      (sum, bill) => sum + (bill.expectedMonthlyAmount ?? 0),
    );
    final paid = activity.paidBills;
    final paidIds = activity.transactions
        .where((transaction) => transaction.categoryType == 'fixed_bill')
        .map((transaction) => transaction.categoryId)
        .toSet();
    final progress = planned == 0 ? 0.0 : (paid / planned).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    if (bills.isEmpty) {
      return _emptyChart(context, 'Add bill amounts to see your bill report.');
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${paidIds.length} of ${bills.length} bills paid',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paid ${formatCurrency(paid)}'),
              Text(
                'Planned ${formatCurrency(planned)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savingsProgressCard(BuildContext context, SavingsProvider savings) {
    final target = savings.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );
    final saved = savings.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.currentAmount,
    );
    final monthlyPlan = savings.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.monthlyContribution,
    );
    final progress = target == 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    if (savings.goals.isEmpty) {
      return _emptyChart(context, 'Create a savings goal to track progress.');
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${savings.goals.length} active goal${savings.goals.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              color: const Color(0xFF2E7D32),
              backgroundColor: const Color(0xFFDCEEDC),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatCurrency(saved)} saved'),
              Text(
                'of ${formatCurrency(target)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          if (monthlyPlan > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Monthly plan: ${formatCurrency(monthlyPlan)}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );

  Widget _categoryCard(BuildContext context, ActivityProvider activity) {
    final entries = activity.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return _emptyChart(context, 'No spending recorded this month.');
    }
    final colors = [
      const Color(0xFF6C3CEB),
      const Color(0xFF2979FF),
      const Color(0xFFFF8A65),
      const Color(0xFF26A69A),
      const Color(0xFFFFC107),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: colors[i % colors.length],
                      radius: 34,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < math.min(entries.length, 5); i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entries[i].key,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatCurrency(entries[i].value),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyCard(BuildContext context, ActivityProvider activity) {
    final maxValue = activity.dailyTotals.values.fold<double>(0, math.max);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: _cardDecoration(),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var day = 1; day <= activity.daysInSelectedMonth; day++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: maxValue == 0
                                ? 0.02
                                : (activity.dailyTotals[day] ?? 0) / maxValue,
                            child: Container(
                              decoration: BoxDecoration(
                                color: activity.dailyTotals.containsKey(day)
                                    ? const Color(0xFF6C3CEB)
                                    : const Color(0xFFE9E0FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (day == 1 ||
                          day == activity.daysInSelectedMonth ||
                          day % 5 == 0)
                        Text(
                          '$day',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        )
                      else
                        const SizedBox(height: 11),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _transactionRow(BuildContext context, Transaction transaction) {
    final isBill = transaction.categoryType == 'fixed_bill';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isBill
                ? const Color(0xFFFFF0D8)
                : const Color(0xFFF0E9FF),
            foregroundColor: isBill
                ? Colors.orange.shade800
                : const Color(0xFF6C3CEB),
            child: Icon(
              isBill
                  ? Icons.receipt_long_outlined
                  : Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.categoryName ?? 'Transaction',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(
                    DateTime.tryParse(transaction.datePaid) ?? DateTime.now(),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            '-${formatCurrency(transaction.amount)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart(BuildContext context, String message) => Container(
    padding: const EdgeInsets.all(28),
    decoration: _cardDecoration(),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );

  Widget _emptyCard(BuildContext context) =>
      _emptyChart(context, 'No transactions recorded this month.');

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
  );

  Widget _errorState(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 58,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.read<ActivityProvider>().load(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
