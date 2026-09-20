import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/shared/models/transaction.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      _transactions = await context.read<ExpenseProvider>().loadTransactions();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Transaction history',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _transactions.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 180),
                        Center(
                          child: Text(
                            'No transactions yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: _transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _transactionCard(_transactions[index]),
                    ),
            ),
    );
  }

  Widget _transactionCard(Transaction transaction) {
    final isBill = transaction.categoryType == 'fixed_bill';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isBill
                ? const Color(0xFFFFF0D8)
                : const Color(0xFFF0E9FF),
            foregroundColor: isBill
                ? Colors.orange.shade800
                : const Color(0xFF6C3CEB),
            child: Icon(
              isBill
                  ? Icons.receipt_long_outlined
                  : Icons.shopping_bag_outlined,
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
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  }
}
