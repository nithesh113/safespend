import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/shared/widgets/currency_text.dart';
import 'package:safespend/shared/widgets/transaction_card.dart';
import 'package:safespend/shared/widgets/status_pill.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/core/theme/app_theme.dart';
import 'package:safespend/core/utils/app_version.dart';
import 'package:intl/intl.dart';

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
    setState(() => _isLoading = true);
    try {
      await context.read<DashboardProvider>().loadDashboardData();
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) {
        _showError('Something went wrong loading the dashboard.');
      }
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
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadData,
        ),
      ),
    );
  }

  Future<void> _markBillPaid(
      int categoryId, String categoryName, double? expectedAmount) async {
    try {
      await context.read<ExpenseProvider>().addTransaction(
            categoryId: categoryId,
            amount: expectedAmount ?? 0.0,
            date: DateTime.now(),
          );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName marked as paid!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) _showError('Failed to mark $categoryName as paid.');
    }
  }

  Future<void> _showPayBillDialog(
      String categoryName, int categoryId, double? expectedAmount) async {
    final amountToPay = expectedAmount ?? 0.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay $categoryName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark this bill as paid for this month?'),
            const SizedBox(height: 8),
            Text(
              'Amount: ${formatCurrency(amountToPay)}',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _markBillPaid(categoryId, categoryName, amountToPay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<DashboardProvider, AppSettingsProvider>(
      builder: (context, dashboard, settings, _) {
        // ----- Loading State -----
        if (_isLoading && !dashboard.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        // ----- Error State (no data loaded at all) -----
        if (!dashboard.hasLoaded && dashboard.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    dashboard.errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
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
        }

        final safeToSpend = dashboard.safeToSpend(settings.monthlyIncome);

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Inline error banner (if data loaded but refresh failed) ----
              if (dashboard.errorMessage != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading:
                        Icon(Icons.warning_amber, color: theme.colorScheme.error),
                    title: Text(dashboard.errorMessage!),
                    trailing: TextButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ),
                ),

              // ---- Safe-to-Spend Header ----
              Card(
                color: AppTheme.green,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe to Spend',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                      const SizedBox(height: 4),
                      CurrencyText(
                        safeToSpend,
                        bold: true,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildBreakdownChip(
                            'Income',
                            settings.monthlyIncome,
                            Colors.white.withAlpha(40),
                            Colors.white,
                          ),
                          _buildBreakdownChip(
                            'Bills',
                            -dashboard.paidFixedBillsTotal -
                                dashboard.pendingFixedBillsTotal,
                            Colors.white.withAlpha(40),
                            Colors.white,
                          ),
                          _buildBreakdownChip(
                            'Saved',
                            -dashboard.totalAllocatedSavings,
                            Colors.white.withAlpha(40),
                            Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---- Fixed Bills Section ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fixed Bills',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${formatCurrency(dashboard.paidFixedBillsTotal)} paid',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: dashboard.fixedBillCategories.isEmpty
                    ? Center(
                        child: Text(
                          'No fixed bills configured.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: dashboard.fixedBillCategories.length,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        itemBuilder: (context, index) {
                          final cat = dashboard.fixedBillCategories[index];
                          final isPaid = dashboard.paidFixedBillsThisMonth.any(
                            (t) => t.categoryId == cat.id,
                          );
                          final expectedAmount =
                              cat.expectedMonthlyAmount ?? 0.0;

                          return GestureDetector(
                            onTap: isPaid
                                ? null
                                : () => _showPayBillDialog(
                                    cat.name, cat.id!, expectedAmount),
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                color: isPaid
                                    ? AppTheme.green.withAlpha(20)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (expectedAmount > 0)
                                        Text(
                                          formatCurrency(expectedAmount),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isPaid
                                                ? AppTheme.green
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      StatusPill(isPaid: isPaid),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 24),

              // ---- Recent Transactions ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Transactions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),

              if (dashboard.recentTransactions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'No transactions yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...dashboard.recentTransactions.map((txn) {
                  return TransactionCard(
                    icon: txn.categoryType == 'fixed_bill'
                        ? Icons.receipt_long
                        : Icons.shopping_cart_outlined,
                    title: txn.categoryName ?? 'Unknown',
                    date: DateTime.tryParse(txn.datePaid) ?? DateTime.now(),
                    amount: txn.amount,
                    note: txn.note,
                  );
                }),

                // App version
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    AppVersion.full,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownChip(
      String label, double amount, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: textColor.withAlpha(200), fontSize: 12),
          ),
          Text(
            formatCurrency(amount),
            style: TextStyle(
                color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}