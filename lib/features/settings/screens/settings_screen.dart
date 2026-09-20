import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/backup/backup_service.dart';
import 'package:safespend/core/security/app_lock_provider.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
        context.read<AppLockProvider>().load(),
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

  Future<void> _editIncome(double current) async {
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly income'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (¥)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount != null && amount > 0) Navigator.pop(ctx, amount);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await context.read<AppSettingsProvider>().setMonthlyIncome(value);
      if (!mounted) return;
      await context.read<DashboardProvider>().loadDashboardData();
      if (mounted) _message('Income updated to ${formatCurrency(value)}');
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    }
  }

  Future<void> _setupPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set app lock PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
                validator: (value) => value == null || value.length < 4
                    ? 'Use at least 4 digits'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                ),
                validator: (value) =>
                    value != pinController.text ? 'PINs do not match' : null,
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
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final pin = pinController.text;
    pinController.dispose();
    confirmController.dispose();
    if (result != true || !mounted) return;
    await context.read<AppLockProvider>().setPin(pin);
    if (mounted) _message('App lock enabled');
  }

  Future<void> _disableLock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable app lock?'),
        content: const Text(
          'Your financial data will open without a PIN or device check.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppLockProvider>().disable();
      _message('App lock disabled');
    }
  }

  Future<String?> _askBackupPassword({required bool confirm}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _BackupPasswordDialog(confirm: confirm),
    );
  }

  Future<void> _exportBackup() async {
    final password = await _askBackupPassword(confirm: true);
    if (password == null || !mounted) return;
    try {
      final bytes = await BackupService.instance.exportEncrypted(password);
      final fileName =
          'safespend_backup_${DateTime.now().toIso8601String().substring(0, 10)}.safespend';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save SafeSpend backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['safespend'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null || !mounted) return;
      if (mounted) _message('Encrypted backup saved');
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    } catch (_) {
      if (mounted) _message('Could not save the backup file.', error: true);
    }
  }

  Future<void> _importBackup() async {
    final settingsProvider = context.read<AppSettingsProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final savingsProvider = context.read<SavingsProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choose SafeSpend backup',
        type: FileType.custom,
        allowedExtensions: const ['safespend'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final password = await _askBackupPassword(confirm: false);
      if (password == null || !mounted) return;
      final backup = await BackupService.instance.decryptBackup(
        bytes,
        password,
      );
      if (!mounted) return;
      final choice = await _showImportPreview(backup);
      if (choice == null || !mounted) return;
      if (choice == _ImportChoice.replace) {
        await BackupService.instance.replace(backup);
      } else {
        await BackupService.instance.merge(backup);
      }
      await Future.wait([
        settingsProvider.loadAll(),
        dashboardProvider.loadDashboardData(),
        savingsProvider.loadGoals(),
        expenseProvider.loadCategories(),
      ]);
      if (mounted) {
        _message(
          choice == _ImportChoice.replace
              ? 'Backup restored successfully'
              : 'Backup merged successfully',
        );
      }
    } on AppException catch (e) {
      if (mounted) _message(e.userMessage, error: true);
    } catch (_) {
      if (mounted) _message('Could not import this backup file.', error: true);
    }
  }

  Future<_ImportChoice?> _showImportPreview(BackupData backup) {
    return showDialog<_ImportChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preview backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exported ${backup.formattedExportDate}'),
            const SizedBox(height: 16),
            _previewRow('Bills', backup.categories.length),
            _previewRow('Transactions', backup.transactions.length),
            _previewRow('Savings goals', backup.goals.length),
            _previewRow('Contributions', backup.contributions.length),
            const SizedBox(height: 14),
            const Text(
              'Replace removes current records. Merge keeps current records and adds only new backup records.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _ImportChoice.merge),
            child: const Text('Merge'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, _ImportChoice.replace),
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer2<AppSettingsProvider, AppLockProvider>(
              builder: (context, settings, lock, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _header(
                    'Money',
                    Icons.account_balance_wallet_outlined,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE4F5E7),
                        foregroundColor: const Color(0xFF2E7D32),
                        child: const Icon(Icons.trending_up),
                      ),
                      title: const Text(
                        'Monthly income',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(formatCurrency(settings.monthlyIncome)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editIncome(settings.monthlyIncome),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _header(
                    'Recurring bills',
                    Icons.receipt_long_outlined,
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.event_repeat_outlined),
                      ),
                      title: const Text(
                        'Manage monthly bills',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${settings.fixedBillCategories.length} bills configured',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/bills'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _header('Privacy', Icons.shield_outlined, theme),
                  const SizedBox(height: 8),
                  _card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFF0D8),
                        foregroundColor: Colors.orange.shade800,
                        child: const Icon(Icons.lock_outline),
                      ),
                      title: Text(
                        lock.enabled
                            ? 'App lock enabled'
                            : 'Protect your finances',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        lock.enabled
                            ? 'PIN and device security are active'
                            : 'Use a PIN and device security when available',
                      ),
                      trailing: Switch(
                        value: lock.enabled,
                        onChanged: (_) =>
                            lock.enabled ? _disableLock() : _setupPin(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _header('Data', Icons.backup_outlined, theme),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.file_upload_outlined),
                          ),
                          title: const Text(
                            'Export encrypted backup',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Save your local data as a protected file.',
                          ),
                          onTap: _exportBackup,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE4F5E7),
                            foregroundColor: const Color(0xFF2E7D32),
                            child: const Icon(Icons.file_download_outlined),
                          ),
                          title: const Text(
                            'Import backup',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Preview and restore or merge a backup file.',
                          ),
                          onTap: _importBackup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _header('About', Icons.info_outline, theme),
                  const SizedBox(height: 8),
                  _card(
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(Icons.offline_bolt_outlined),
                      ),
                      title: Text(
                        'Local-only storage',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Your SafeSpend data stays on this device.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _header(String title, IconData icon, ThemeData theme) => Row(
    children: [
      Icon(icon, size: 20, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

enum _ImportChoice { replace, merge }

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.trim().length < 6) {
      setState(() => _error = 'Use at least 6 characters.');
      return;
    }
    if (widget.confirm && password != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.confirm ? 'Protect backup' : 'Unlock backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Backup password'),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirm ? 'Export' : 'Unlock'),
        ),
      ],
    );
  }
}
