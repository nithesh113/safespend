import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/shared/models/transaction.dart';
import 'package:safespend/shared/models/category.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Transaction> _recentTransactions = [];
  List<Category> _fixedBillCategories = [];
  List<Transaction> _paidFixedBillsThisMonth = [];
  double _monthlyVariableExpenses = 0.0;
  double _monthlySavingsContributions = 0.0;
  String? _errorMessage;

  List<Transaction> get recentTransactions => _recentTransactions;
  List<Category> get fixedBillCategories => _fixedBillCategories;
  List<Transaction> get paidFixedBillsThisMonth => _paidFixedBillsThisMonth;
  double get totalAllocatedSavings => _monthlySavingsContributions;
  double get monthlyVariableExpenses => _monthlyVariableExpenses;
  double get monthlySavingsContributions => _monthlySavingsContributions;
  String? get errorMessage => _errorMessage;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// Only counts enabled bills that have an amount set
  double get pendingFixedBillsTotal {
    double total = 0.0;
    for (final cat in _fixedBillCategories) {
      final isPaid = _paidFixedBillsThisMonth.any(
        (t) => t.categoryId == cat.id,
      );
      if (cat.enabled && !isPaid && (cat.expectedMonthlyAmount ?? 0) > 0) {
        total += cat.expectedMonthlyAmount!;
      }
    }
    return total;
  }

  double get paidFixedBillsTotal {
    double total = 0.0;
    for (final txn in _paidFixedBillsThisMonth) {
      total += txn.amount;
    }
    return total;
  }

  double safeToSpend(double monthlyIncome) {
    final result =
        monthlyIncome -
        _monthlyVariableExpenses -
        paidFixedBillsTotal -
        pendingFixedBillsTotal -
        _monthlySavingsContributions;
    return result.clamp(0.0, double.infinity);
  }

  Future<void> loadDashboardData() async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      final monthStart = _monthDate(DateTime(now.year, now.month, 1));
      final monthEnd = _monthDate(DateTime(now.year, now.month + 1, 0));

      final txnMaps = await db.rawQuery('''
        SELECT t.*, c.name as category_name, c.type as category_type
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        ORDER BY t.date_paid DESC, t.id DESC
        LIMIT 5
      ''');
      _recentTransactions = txnMaps.map((m) => Transaction.fromMap(m)).toList();

      // Only enabled fixed bills
      final catMaps = await db.query(
        'categories',
        where: 'type = ? AND enabled = 1 AND archived = 0',
        whereArgs: ['fixed_bill'],
      );
      _fixedBillCategories = catMaps.map((m) => Category.fromMap(m)).toList();

      final paidMaps = await db.rawQuery(
        '''
        SELECT t.*, c.name as category_name, c.type as category_type
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE c.type = 'fixed_bill'
          AND t.date_paid >= ? AND t.date_paid <= ?
      ''',
        [monthStart, monthEnd],
      );
      _paidFixedBillsThisMonth = paidMaps
          .map((m) => Transaction.fromMap(m))
          .toList();

      final expenseResult = await db.rawQuery(
        '''
        SELECT SUM(t.amount) as total
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE c.type = 'variable_expense'
          AND t.date_paid >= ? AND t.date_paid <= ?
      ''',
        [monthStart, monthEnd],
      );
      _monthlyVariableExpenses =
          (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

      final savingsResult = await db.rawQuery(
        '''
        SELECT SUM(amount) as total
        FROM savings_contributions
        WHERE contributed_at >= ? AND contributed_at <= ?
      ''',
        [monthStart, monthEnd],
      );
      _monthlySavingsContributions =
          (savingsResult.first['total'] as num?)?.toDouble() ?? 0.0;

      _errorMessage = null;
      _hasLoaded = true;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error loading dashboard: $e\n$stackTrace');
      _errorMessage = 'Could not load dashboard data. Pull down to retry.';
      notifyListeners();
    }
  }

  String _monthDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
