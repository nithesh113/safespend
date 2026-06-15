import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/core/utils/app_exception.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AppSettingsProvider>().loadAll();
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (_) {
      if (mounted) _showError('Failed to load settings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editIncome(double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly Income'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount (¥)', filled: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final v = double.tryParse(ctrl.text.trim());
            if (v != null && v > 0) Navigator.pop(ctx, v);
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        await context.read<AppSettingsProvider>().setMonthlyIncome(result);
        _refreshDashboard();
        _showSuccess('Income updated to ${formatCurrency(result)}');
      } on AppException catch (e) { if (mounted) _showError(e.userMessage); }
      catch (_) { if (mounted) _showError('Failed to save income.'); }
    }
  }

  Future<void> _editBillAmount(int catId, String name, double? current) async {
    final ctrl = TextEditingController(text: (current ?? 0).toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name Amount'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Monthly amount (¥)', filled: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final v = double.tryParse(ctrl.text.trim());
            if (v != null) Navigator.pop(ctx, v);
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        await context.read<AppSettingsProvider>().setCategoryAmount(catId, result);
        _refreshDashboard();
        _showSuccess('$name updated');
      } on AppException catch (e) { if (mounted) _showError(e.userMessage); }
      catch (_) { if (mounted) _showError('Failed to update $name.'); }
    }
  }

  Future<void> _toggleBill(int catId, bool current) async {
    try {
      await context.read<AppSettingsProvider>().toggleCategory(catId, !current);
      _refreshDashboard();
    } on AppException catch (e) { if (mounted) _showError(e.userMessage); }
    catch (_) { if (mounted) _showError('Failed to toggle bill.'); }
  }

  void _refreshDashboard() {
    try { context.read<DashboardProvider>().loadDashboardData(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        final bills = settings.fixedBillCategories;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ---- SECTION: Income ----
            _sectionHeader('Income', Icons.account_balance_wallet, theme),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _editIncome(settings.monthlyIncome),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.trending_up, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Income', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(formatCurrency(settings.monthlyIncome),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2E7D32))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ---- SECTION: Fixed Bills ----
            _sectionHeader('Fixed Bills', Icons.receipt_long, theme),
            const SizedBox(height: 4),
            Text('Tap a bill to edit its amount. Toggle to enable/disable.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),

            const SizedBox(height: 12),

            ...bills.map((cat) {
              final amount = cat.expectedMonthlyAmount ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: cat.enabled ? null : theme.colorScheme.surfaceContainerHighest,
                  child: InkWell(
                    onTap: cat.enabled ? () => _editBillAmount(cat.id!, cat.name, cat.expectedMonthlyAmount) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: cat.enabled
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _billIcon(cat.name),
                              color: cat.enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name, style: theme.textTheme.titleMedium?.copyWith(
                                    color: cat.enabled ? null : theme.colorScheme.onSurfaceVariant)),
                                Text(formatCurrency(amount),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cat.enabled
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Switch(
                            value: cat.enabled,
                            onChanged: (_) => _toggleBill(cat.id!, cat.enabled),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  IconData _billIcon(String name) {
    switch (name.toLowerCase()) {
      case 'rent': return Icons.home;
      case 'water': return Icons.water_drop;
      case 'electricity': return Icons.bolt;
      case 'wifi': return Icons.wifi;
      default: return Icons.receipt_long;
    }
  }
}