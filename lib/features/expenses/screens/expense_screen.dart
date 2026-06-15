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
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _valid => _amountText.isNotEmpty && _selectedCategoryId != null && (double.tryParse(_amountText) ?? 0) > 0;

  @override
  void initState() { super.initState(); _loadCats(); }
  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _loadCats() async {
    try { await context.read<ExpenseProvider>().loadCategories(); }
    on AppException catch (e) { if (mounted) _err(e.userMessage); }
    catch (_) { if (mounted) _err('Failed to load categories.'); }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));

  void _digit(String d) { if (_amountText.length < 9) setState(() => _amountText += d); }
  void _del() { if (_amountText.isNotEmpty) setState(() => _amountText = _amountText.substring(0, _amountText.length - 1)); }
  void _clr() => setState(() => _amountText = '');

  Future<void> _save() async {
    final a = double.tryParse(_amountText);
    if (a == null || a <= 0 || _selectedCategoryId == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ExpenseProvider>().addTransaction(
        categoryId: _selectedCategoryId!, amount: a, date: _selectedDate,
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      );
      try { if (mounted) await context.read<DashboardProvider>().loadDashboardData(); } catch (_) {}
      _clearForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved!'), behavior: SnackBarBehavior.floating));
    } on AppException catch (e) { if (mounted) _err(e.userMessage); }
    catch (_) { if (mounted) _err('Failed to save.'); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  void _clearForm() { setState(() { _amountText = ''; _noteCtrl.clear(); }); }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context, initialDate: _selectedDate,
        firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (p != null) setState(() => _selectedDate = p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ExpenseProvider>(
      builder: (context, p, _) {
        final cats = p.variableExpenseCategories;
        return Column(children: [
          Expanded(flex: 3, child: ListView(padding: const EdgeInsets.all(20), children: [
            if (p.errorMessage != null)
              Card(color: theme.colorScheme.errorContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(padding: const EdgeInsets.all(12),
                      child: Row(children: [const Icon(Icons.warning_amber, size: 18), const SizedBox(width: 8),
                        Expanded(child: Text(p.errorMessage!, style: theme.textTheme.bodySmall)),
                        TextButton(onPressed: _loadCats, child: const Text('Retry'))],))),
            if (p.errorMessage != null) const SizedBox(height: 12),

            // Amount card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: Colors.white,
              child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                Text('Enter Amount', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                CurrencyText(double.tryParse(_amountText.isEmpty ? '0' : _amountText) ?? 0,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
              ])),
            ),

            const SizedBox(height: 14),

            // Date row
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                trailing: TextButton(onPressed: _pickDate, child: const Text('Change')),
              ),
            ),

            const SizedBox(height: 8),

            // Category chips
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Category', style: theme.textTheme.labelLarge),
                const SizedBox(height: 10),
                if (cats.isNotEmpty)
                  Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) {
                    final sel = _selectedCategoryId == c.id;
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: sel,
                      selectedColor: theme.colorScheme.primary.withAlpha(30),
                      onSelected: (_) => setState(() => _selectedCategoryId = sel ? null : c.id),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    );
                  }).toList())
                else
                  Text('No categories loaded', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Add a note...', prefixIcon: const Icon(Icons.notes),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 50,
              child: FilledButton.icon(
                onPressed: _valid && !_isSaving ? _save : null,
                icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Transaction'),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
          ])),
          Expanded(flex: 2, child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, -2))]),
            child: CustomNumPad(onDigitPressed: _digit, onBackspacePressed: _del, onClearPressed: _clr),
          )),
        ]);
      },
    );
  }
}