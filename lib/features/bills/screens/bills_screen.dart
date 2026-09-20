import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/core/notifications/bill_notification_service.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/shared/models/category.dart';
import 'package:safespend/shared/widgets/status_pill.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      await Future.wait([
        context.read<AppSettingsProvider>().loadAll(),
        context.read<DashboardProvider>().loadDashboardData(),
      ]);
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _addBill() async {
    final result = await showDialog<_BillFormResult>(
      context: context,
      builder: (_) => const _BillEditorDialog(),
    );
    if (result == null || !mounted) return;
    try {
      final settings = context.read<AppSettingsProvider>();
      final created = await settings.createRecurringBill(
        name: result.name,
        amount: result.amount,
        dueDay: result.dueDay,
      );
      final permission = await BillNotificationService.instance
          .requestPermission();
      if (!permission && mounted) {
        await settings.toggleCategoryReminder(created.id!, false);
      } else if (permission) {
        // The bill is created before Android permission is requested. Re-sync
        // after permission is granted so its first reminder is registered.
        await BillNotificationService.instance.syncBills(
          settings.allCategories,
        );
      }
      await _load();
      if (mounted) _message('${result.name} added to your monthly bills');
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    }
  }

  Future<void> _editBill(Category bill) async {
    final result = await showDialog<_BillFormResult>(
      context: context,
      builder: (_) => _BillEditorDialog(bill: bill),
    );
    if (result == null || !mounted) return;
    try {
      final settings = context.read<AppSettingsProvider>();
      await settings.setCategoryAmount(bill.id!, result.amount);
      await settings.setCategoryDueDay(bill.id!, result.dueDay);
      await _load();
      if (mounted) _message('${bill.name} updated');
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    }
  }

  Future<void> _deleteBill(Category bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${bill.name}?'),
        content: const Text(
          'This bill will be removed from your recurring bills. Previous payment history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppSettingsProvider>().deleteRecurringBill(bill.id!);
      await _load();
      if (mounted) _message('${bill.name} deleted');
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    }
  }

  Future<void> _toggleReminder(Category bill, bool enabled) async {
    final settings = context.read<AppSettingsProvider>();
    if (enabled) {
      final permission = await BillNotificationService.instance
          .requestPermission();
      if (!permission) {
        if (mounted) {
          _message(
            'Notification permission is required for bill reminders.',
            error: true,
          );
        }
        return;
      }
    }
    try {
      await settings.toggleCategoryReminder(bill.id!, enabled);
      if (mounted) {
        _message(enabled ? 'Reminder enabled' : 'Reminder disabled');
      }
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring bills',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _addBill,
            tooltip: 'Add recurring bill',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer2<AppSettingsProvider, DashboardProvider>(
              builder: (context, settings, dashboard, _) {
                final bills = settings.fixedBillCategories;
                if (bills.isEmpty) {
                  return _emptyState(theme);
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: bills.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final bill = bills[index];
                      final paid = dashboard.paidFixedBillsThisMonth.any(
                        (t) => t.categoryId == bill.id,
                      );
                      return _billCard(bill, paid, theme);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _billCard(Category bill, bool paid, ThemeData theme) {
    final dueText = 'Every month on the ${bill.dueDay}${_ordinal(bill.dueDay)}';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _editBill(bill),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.primary,
                child: Icon(_iconFor(bill.name)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(bill.expectedMonthlyAmount ?? 0),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      dueText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusPill(isPaid: paid),
                      PopupMenuButton<String>(
                        tooltip: 'Bill options',
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editBill(bill);
                          } else if (value == 'delete') {
                            _deleteBill(bill);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Semantics(
                    label: 'Reminder for ${bill.name}',
                    toggled: bill.reminderEnabled,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bill.reminderEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        Switch(
                          value: bill.reminderEnabled,
                          onChanged: (value) => _toggleReminder(bill, value),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: bill.enabled,
                    onChanged: (value) async {
                      await context.read<AppSettingsProvider>().toggleCategory(
                        bill.id!,
                        value,
                      );
                      await _load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No recurring bills yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add rent, WiFi, phone, insurance, or any bill you pay every month.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _addBill,
            icon: const Icon(Icons.add),
            label: const Text('Add your first bill'),
          ),
        ],
      ),
    ),
  );

  String _ordinal(int day) {
    if (day % 100 >= 11 && day % 100 <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  IconData _iconFor(String name) {
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

class _BillFormResult {
  const _BillFormResult({
    required this.name,
    required this.amount,
    required this.dueDay,
  });

  final String name;
  final double amount;
  final int dueDay;
}

class _BillEditorDialog extends StatefulWidget {
  const _BillEditorDialog({this.bill});

  final Category? bill;

  @override
  State<_BillEditorDialog> createState() => _BillEditorDialogState();
}

class _BillEditorDialogState extends State<_BillEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dueDayController;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bill?.name ?? '');
    _amountController = TextEditingController(
      text: (widget.bill?.expectedMonthlyAmount ?? 0).toStringAsFixed(0),
    );
    _dueDayController = TextEditingController(
      text: (widget.bill?.dueDay ?? 1).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _BillFormResult(
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        dueDay: int.parse(_dueDayController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit ${widget.bill!.name}' : 'Add recurring bill',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditing) ...[
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bill name',
                  hintText: 'e.g. Room rent',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly amount (¥)',
              ),
              validator: (value) =>
                  (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                  ? 'Enter a valid amount'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dueDayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Due day of month (1–31)',
              ),
              validator: (value) {
                final day = int.tryParse(value?.trim() ?? '');
                return day == null || day < 1 || day > 31
                    ? 'Use a day from 1 to 31'
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add bill'),
        ),
      ],
    );
  }
}
