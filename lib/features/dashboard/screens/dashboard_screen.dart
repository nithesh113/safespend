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
import 'package:safespend/core/utils/app_version.dart';
import 'package:go_router/go_router.dart';
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
      await Future.wait([
        context.read<DashboardProvider>().loadDashboardData(),
        context.read<AppSettingsProvider>().loadAll(),
      ]);
    } on AppException catch (e) { if (mounted) _showError(e.userMessage); }
    catch (_) { if (mounted) _showError('Something went wrong.'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _loadData)),
    );
  }

  Future<void> _markBillPaid(int categoryId, String categoryName, double? expectedAmount) async {
    try {
      await context.read<ExpenseProvider>().addTransaction(
            categoryId: categoryId, amount: expectedAmount ?? 0, date: DateTime.now());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$categoryName marked as paid!'), behavior: SnackBarBehavior.floating));
      }
    } on AppException catch (e) { if (mounted) _showError(e.userMessage); }
    catch (_) { if (mounted) _showError('Failed to mark $categoryName as paid.'); }
  }

  Future<void> _showPayBillDialog(String categoryName, int categoryId, double? expectedAmount) async {
    final amount = expectedAmount ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay $categoryName'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mark this bill as paid for this month?'),
          const SizedBox(height: 8),
          Text('Amount: ${formatCurrency(amount)}',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) await _markBillPaid(categoryId, categoryName, amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<DashboardProvider, AppSettingsProvider>(
      builder: (context, dashboard, settings, _) {
        if (_isLoading && !dashboard.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!dashboard.hasLoaded && dashboard.errorMessage != null) {
          return Center(
            child: Padding(padding: const EdgeInsets.all(32), child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(dashboard.errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            )),
          );
        }

        final safeToSpend = dashboard.safeToSpend(settings.monthlyIncome);
        final bills = dashboard.fixedBillCategories;

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ---- Settings gear ----
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => context.go('/settings'),
                ),
              ),

              // ---- Error banner ----
              if (dashboard.errorMessage != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dashboard.errorMessage!, style: theme.textTheme.bodySmall)),
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ]),
                  ),
                ),
              if (dashboard.errorMessage != null) const SizedBox(height: 12),

              // ---- Safe-to-Spend Card ----
              _buildSafeToSpendCard(safeToSpend, dashboard, theme),
              const SizedBox(height: 24),

              // ---- Fixed Bills ----
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Fixed Bills', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${formatCurrency(dashboard.paidFixedBillsTotal)} paid',
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              if (bills.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No fixed bills enabled.\nGo to Settings to configure.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: bills.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final cat = bills[index];
                      final isPaid = dashboard.paidFixedBillsThisMonth.any((t) => t.categoryId == cat.id);
                      final amount = cat.expectedMonthlyAmount ?? 0;
                      return GestureDetector(
                        onTap: isPaid ? null : () => _showPayBillDialog(cat.name, cat.id!, amount),
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 14),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: isPaid ? const Color(0xFF2E7D32).withAlpha(15) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(cat.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                    StatusPill(isPaid: isPaid),
                                  ]),
                                  if (amount > 0)
                                    Text(formatCurrency(amount),
                                        style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isPaid ? const Color(0xFF2E7D32) : theme.colorScheme.onSurface)),
                                  if (amount == 0)
                                    Text('Tap to set amount',
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Recent', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              if (dashboard.recentTransactions.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('No transactions yet', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                )
              else
                ...dashboard.recentTransactions.map((txn) => TransactionCard(
                      icon: txn.categoryType == 'fixed_bill' ? Icons.receipt_long : Icons.shopping_cart_outlined,
                      title: txn.categoryName ?? 'Unknown',
                      date: DateTime.tryParse(txn.datePaid) ?? DateTime.now(),
                      amount: txn.amount,
                      note: txn.note,
                    )),

              const SizedBox(height: 24),
              Center(
                child: Text(AppVersion.full,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSafeToSpendCard(double safeToSpend, DashboardProvider dashboard, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Safe to Spend', style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        CurrencyText(safeToSpend, bold: true,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: [
          _chip('Income', dashboard.paidFixedBillsTotal + dashboard.pendingFixedBillsTotal + dashboard.totalAllocatedSavings + safeToSpend,
              Colors.white.withAlpha(35), Colors.white, false),
          _chip('Bills', -dashboard.paidFixedBillsTotal - dashboard.pendingFixedBillsTotal,
              Colors.white.withAlpha(35), Colors.white, false),
          _chip('Saved', -dashboard.totalAllocatedSavings,
              Colors.white.withAlpha(35), Colors.white, false),
        ]),
      ]),
    );
  }

  Widget _chip(String label, double amount, Color bg, Color fg, bool bold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: fg.withAlpha(180), fontSize: 12)),
        Text(formatCurrency(amount), style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}