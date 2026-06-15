import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/shared/widgets/custom_num_pad.dart';
import 'package:safespend/shared/widgets/currency_text.dart';
import 'package:safespend/core/utils/app_exception.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _amountText = '';
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  bool get _isValid =>
      _amountText.isNotEmpty &&
      _selectedCategoryId != null &&
      (double.tryParse(_amountText) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      await context.read<ExpenseProvider>().loadCategories();
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) _showError('Failed to load categories.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _addDigit(String digit) {
    // Prevent unreasonably large numbers (> 9 digits)
    if (_amountText.length >= 9) return;
    setState(() => _amountText += digit);
  }

  void _removeDigit() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  void _clear() {
    setState(() => _amountText = '');
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0 || _selectedCategoryId == null) return;
    if (_isSaving) return; // Prevent double-tap

    setState(() => _isSaving = true);
    try {
      await context.read<ExpenseProvider>().addTransaction(
            categoryId: _selectedCategoryId!,
            amount: amount,
            date: _selectedDate,
            note: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
          );

      // Refresh dashboard in background — don't block the UI flow
      try {
        if (mounted) {
          await context.read<DashboardProvider>().loadDashboardData();
        }
      } catch (_) {
        // Dashboard refresh failed, but the transaction was saved.
        // The user can pull-to-refresh on the dashboard later.
      }

      _clearForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) _showError(e.userMessage);
    } catch (e) {
      if (mounted) _showError('Failed to save transaction. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _amountText = '';
      _noteController.clear();
    });
  }

  Future<void> _pickDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        helpText: 'Select transaction date',
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
      }
    } catch (e) {
      // Date picker can rarely fail on some devices
      if (mounted) _showError('Could not open date picker.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final categories = provider.variableExpenseCategories;
        final displayAmount = _amountText.isEmpty ? '0' : _amountText;

        return Column(
          children: [
            // ---- Upper Half: Amount & Selectors ----
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Error banner for category loading failures
                  if (provider.errorMessage != null)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber,
                            color: theme.colorScheme.error),
                        title: Text(provider.errorMessage!),
                        trailing: TextButton(
                          onPressed: _loadCategories,
                          child: const Text('Retry'),
                        ),
                      ),
                    ),

                  // Amount display
                  Card(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Enter Amount',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CurrencyText(
                            double.tryParse(displayAmount) ?? 0,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date selector
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('Change'),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),

                  const SizedBox(height: 8),

                  // Category selector
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Category'),
                    subtitle: Text(
                      () {
                        if (_selectedCategoryId == null) {
                          return 'Select a category';
                        }
                        final cat = categories.firstWhere(
                          (c) => c.id == _selectedCategoryId,
                          orElse: () => categories.first,
                        );
                        return categories.isEmpty
                            ? 'No categories loaded'
                            : cat.name;
                      }(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),

                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId =
                                  selected ? cat.id : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Note field
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: const Icon(Icons.notes),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          _isValid && !_isSaving ? _saveTransaction : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Transaction'),
                    ),
                  ),
                ],
              ),
            ),

            // ---- Lower Half: Custom NumPad ----
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: CustomNumPad(
                  onDigitPressed: _addDigit,
                  onBackspacePressed: _removeDigit,
                  onClearPressed: _clear,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}