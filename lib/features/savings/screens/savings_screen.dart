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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try { await context.read<SavingsProvider>().loadGoals(); }
    on AppException catch (e) { if (mounted) _err(e.userMessage); }
    catch (_) { if (mounted) _err('Failed to load savings goals.'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating));

  Future<void> _refreshDashboard() async {
    try { if (mounted) await context.read<DashboardProvider>().loadDashboardData(); } catch (_) {}
  }

  Future<void> _createGoal() async {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    DateTime? target;
    final sm = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, sd) => AlertDialog(
        title: const Text('New Savings Goal'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g., New Phone', filled: true)),
          const SizedBox(height: 12),
          TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target (¥)', filled: true)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(target == null ? 'Optional deadline' : DateFormat('MMM dd, yyyy').format(target!)),
            trailing: target != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => sd(() => target = null)) : null,
            onTap: () async {
              final p = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2035));
              if (p != null) sd(() => target = p);
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (titleCtrl.text.trim().isNotEmpty && amtCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true); },
              child: const Text('Create')),
        ],
      ),
    ));
    if (ok != true || !mounted) return;
    try {
      await context.read<SavingsProvider>().createGoal(
        title: titleCtrl.text.trim(),
        targetAmount: double.tryParse(amtCtrl.text.trim()) ?? 0,
        targetDate: target != null ? DateFormat('yyyy-MM-dd').format(target!) : null,
      );
      await _refreshDashboard();
      sm.showSnackBar(const SnackBar(content: Text('Goal created!'), behavior: SnackBarBehavior.floating));
    } on AppException catch (e) { sm.showSnackBar(SnackBar(content: Text(e.userMessage), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
    catch (_) { sm.showSnackBar(SnackBar(content: const Text('Failed to create goal.'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
  }

  Future<void> _addFunds(SavingsProvider p, int id, String title, double current) async {
    final ctrl = TextEditingController();
    final sm = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Funds', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('$title · Current: ${formatCurrency(current)}'),
          const SizedBox(height: 16),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
              decoration: const InputDecoration(labelText: 'Amount (¥)', filled: true, border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async {
              final a = double.tryParse(ctrl.text.trim());
              if (a == null || a <= 0) return;
              try {
                await p.addFunds(id, a);
                await _refreshDashboard();
                if (ctx.mounted) { Navigator.pop(ctx); sm.showSnackBar(SnackBar(content: Text('Added ${formatCurrency(a)}'), behavior: SnackBarBehavior.floating)); }
              } on AppException catch (e) { if (ctx.mounted) sm.showSnackBar(SnackBar(content: Text(e.userMessage), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
              catch (_) { if (ctx.mounted) sm.showSnackBar(SnackBar(content: const Text('Failed to add funds.'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating)); }
            },
            child: const Text('Add Funds'),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<SavingsProvider>(builder: (context, p, _) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      final goals = p.goals;
      return Scaffold(
        body: goals.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (p.errorMessage != null) ...[
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(p.errorMessage!, textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ] else ...[
            Container(width: 72, height: 72, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.savings_outlined, size: 36, color: theme.colorScheme.primary)),
            const SizedBox(height: 20),
            Text('No savings goals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Create your first goal!', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ])) : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            itemCount: goals.length,
            itemBuilder: (_, i) {
              final g = goals[i];
              return ProgressJarCard(title: g.title, targetAmount: g.targetAmount, currentAmount: g.currentAmount,
                  targetDate: g.targetDate, onTap: () => _addFunds(p, g.id!, g.title, g.currentAmount));
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createGoal, icon: const Icon(Icons.add), label: const Text('New Goal')),
      );
    });
  }
}