import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';
import 'package:safespend/shared/models/category.dart';
import 'package:safespend/shared/widgets/status_pill.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        context.read<DashboardProvider>().loadDashboardData(),
        context.read<AppSettingsProvider>().loadAll(),
        context.read<SavingsProvider>().loadGoals(),
      ]);
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (_) {
      if (mounted) _showError('Something went wrong while loading SafeSpend.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _markBillPaid(Category bill) async {
    final amount = bill.expectedMonthlyAmount ?? 0;
    if (amount <= 0) {
      context.go('/bills');
      return;
    }
    try {
      await context.read<ExpenseProvider>().addTransaction(
        categoryId: bill.id!,
        amount: amount,
        date: DateTime.now(),
        note: 'Monthly bill payment',
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bill.name} marked as paid'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (_) {
      if (mounted) _showError('Could not mark ${bill.name} as paid.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<DashboardProvider, AppSettingsProvider, SavingsProvider>(
      builder: (context, dashboard, settings, savings, _) {
        if (_isLoading && !dashboard.hasLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!dashboard.hasLoaded && dashboard.errorMessage != null) {
          return Scaffold(body: _errorState(dashboard.errorMessage!));
        }

        final safeToSpend = dashboard.safeToSpend(settings.monthlyIncome);
        final now = DateTime.now();
        final greeting = now.hour < 12
            ? 'Good morning'
            : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your SafeSpend',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      _roundButton(
                        Icons.settings_outlined,
                        () => context.go('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _balanceCard(safeToSpend, settings.monthlyIncome, dashboard),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Upcoming payments',
                    'See all',
                    () => context.go('/bills'),
                  ),
                  const SizedBox(height: 10),
                  _billStrip(dashboard),
                  const SizedBox(height: 22),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _quickActions(),
                  const SizedBox(height: 22),
                  _savingsCard(savings),
                  const SizedBox(height: 22),
                  _sectionHeader(
                    'Recent transactions',
                    'See all',
                    () => context.go('/activity'),
                  ),
                  const SizedBox(height: 8),
                  if (dashboard.recentTransactions.isEmpty)
                    _emptyCard(
                      Icons.receipt_long_outlined,
                      'No transactions yet',
                      'Your recent spending will appear here.',
                    )
                  else
                    ...dashboard.recentTransactions.map(
                      (transaction) => _transactionRow(transaction),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _balanceCard(
    double safeToSpend,
    double income,
    DashboardProvider dashboard,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9E0FF), Color(0xFFBFA7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Safe to spend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(safeToSpend),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF382067),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _balanceStat('Income', income),
              _balanceStat(
                'Spent',
                dashboard.monthlyVariableExpenses +
                    dashboard.paidFixedBillsTotal,
              ),
              _balanceStat('Saved', dashboard.monthlySavingsContributions),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceStat(String label, double value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 3),
        Text(
          formatCurrency(value),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _billStrip(DashboardProvider dashboard) {
    if (dashboard.fixedBillCategories.isEmpty) {
      return _emptyCard(
        Icons.event_note_outlined,
        'No recurring bills',
        'Add the bills you pay every month.',
      );
    }
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dashboard.fixedBillCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final bill = dashboard.fixedBillCategories[index];
          final paid = dashboard.paidFixedBillsThisMonth.any(
            (t) => t.categoryId == bill.id,
          );
          final days = _daysUntilDue(bill.dueDay);
          return InkWell(
            onTap: paid ? null : () => _confirmPayBill(bill),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 174,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: paid ? const Color(0xFFE5F5E9) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: paid
                      ? const Color(0xFFB7E5C1)
                      : const Color(0xFFEDEAF4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF0E9FF),
                        child: Icon(
                          _billIcon(bill.name),
                          size: 17,
                          color: const Color(0xFF6C3CEB),
                        ),
                      ),
                      StatusPill(isPaid: paid),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    bill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(bill.expectedMonthlyAmount ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paid
                        ? 'Paid this month'
                        : days < 0
                        ? '${-days} days overdue'
                        : days == 0
                        ? 'Due today'
                        : '$days days left',
                    style: TextStyle(
                      fontSize: 12,
                      color: paid ? const Color(0xFF2E7D32) : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmPayBill(Category bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark ${bill.name} paid?'),
        content: Text(
          '${formatCurrency(bill.expectedMonthlyAmount ?? 0)} will be recorded for ${DateFormat('MMMM').format(DateTime.now())}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _markBillPaid(bill);
  }

  Widget _quickActions() => Row(
    children: [
      _quickAction(
        Icons.shopping_bag_outlined,
        'Expense',
        () => context.go('/expenses'),
      ),
      _quickAction(
        Icons.receipt_long_outlined,
        'Bill',
        () => context.go('/bills'),
      ),
      _quickAction(
        Icons.savings_outlined,
        'Goal',
        () => context.go('/savings'),
      ),
      _quickAction(
        Icons.history_rounded,
        'History',
        () => context.go('/activity'),
      ),
    ],
  );

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(icon, color: const Color(0xFF6C3CEB)),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _savingsCard(SavingsProvider savings) {
    final totalTarget = savings.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );
    final totalSaved = savings.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.currentAmount,
    );
    final progress = totalTarget <= 0
        ? 0.0
        : (totalSaved / totalTarget).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => context.go('/savings'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFEDE8FB),
                    color: const Color(0xFF6C3CEB),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Savings goals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatCurrency(totalSaved)} saved of ${formatCurrency(totalTarget)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    savings.goals.isEmpty
                        ? 'Create your first goal'
                        : '${savings.goals.length} active goal${savings.goals.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _transactionRow(dynamic transaction) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFF0E9FF),
          foregroundColor: const Color(0xFF6C3CEB),
          child: Icon(
            transaction.categoryType == 'fixed_bill'
                ? Icons.receipt_long
                : Icons.shopping_bag_outlined,
            size: 19,
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

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );

  Widget _emptyCard(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF6C3CEB)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _roundButton(IconData icon, VoidCallback onTap) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: IconButton(onPressed: onTap, icon: Icon(icon)),
  );

  int _daysUntilDue(int dueDay) {
    final now = DateTime.now();
    final day = dueDay.clamp(1, DateUtils.getDaysInMonth(now.year, now.month));
    final due = DateTime(now.year, now.month, day);
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  IconData _billIcon(String name) {
    switch (name.toLowerCase()) {
      case 'rent':
      case 'room rent':
        return Icons.home_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'electricity':
        return Icons.bolt_outlined;
      case 'wifi':
        return Icons.wifi_outlined;
      case 'phone':
        return Icons.phone_android_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}
