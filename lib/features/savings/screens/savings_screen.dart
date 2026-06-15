import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/shared/widgets/progress_jar_card.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/core/utils/app_exception.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      await context.read<SavingsProvider>().loadGoals();
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) _showError('Failed to load savings goals.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Refreshes the dashboard data in the background.
  /// Silently swallows errors — the dashboard has its own error handling.
  Future<void> _refreshDashboard() async {
    try {
      if (mounted) {
        await context.read<DashboardProvider>().loadDashboardData();
      }
    } catch (_) {}
  }

  Future<void> _showCreateGoalDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? targetDate;

    // Capture these before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Savings Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g., New Phone',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Amount (¥)',
                    hintText: 'e.g., 150000',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(targetDate == null
                      ? 'Optional target date'
                      : DateFormat('MMM dd, yyyy').format(targetDate!)),
                  trailing: targetDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setDialogState(() => targetDate = null),
                        )
                      : null,
                  onTap: () async {
                    try {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => targetDate = picked);
                      }
                    } catch (_) {
                      // Date picker failure — just ignore
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty &&
                    amountController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return; // User cancelled
    if (!mounted) return;

    try {
      await context.read<SavingsProvider>().createGoal(
            title: titleController.text.trim(),
            targetAmount:
                double.tryParse(amountController.text.trim()) ?? 0.0,
            targetDate: targetDate != null
                ? DateFormat('yyyy-MM-dd').format(targetDate!)
                : null,
          );
      await _refreshDashboard();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Savings goal created!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to create savings goal.'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showAddFundsSheet(
      SavingsProvider provider, int goalId, String title, double currentAmount) async {
    final controller = TextEditingController();

    // Capture before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Funds — $title',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('Current: ${formatCurrency(currentAmount)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount to add (¥)',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(controller.text.trim());
                  if (amount == null || amount <= 0) return;

                  try {
                    await provider.addFunds(goalId, amount);
                    await _refreshDashboard();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                              'Added ${formatCurrency(amount)} to $title'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } on AppException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(e.userMessage),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Failed to add funds. Please try again.'),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add Funds'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SavingsProvider>(
      builder: (context, provider, _) {
        // ----- Loading state -----
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final goals = provider.goals;

        return Scaffold(
          body: goals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (provider.errorMessage != null) ...[
                        Icon(Icons.error_outline,
                            size: 64, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadGoals,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ] else ...[
                        Icon(Icons.savings_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No savings goals yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first goal to start saving!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGoals,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return ProgressJarCard(
                        title: goal.title,
                        targetAmount: goal.targetAmount,
                        currentAmount: goal.currentAmount,
                        targetDate: goal.targetDate,
                        onTap: () => _showAddFundsSheet(
                            provider, goal.id!, goal.title, goal.currentAmount),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateGoalDialog,
            icon: const Icon(Icons.add),
            label: const Text('New Goal'),
          ),
        );
      },
    );
  }
}