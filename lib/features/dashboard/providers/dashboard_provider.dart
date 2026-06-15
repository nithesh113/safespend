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
  double _totalAllocatedSavings = 0.0;
  String? _errorMessage;

  List<Transaction> get recentTransactions => _recentTransactions;
  List<Category> get fixedBillCategories => _fixedBillCategories;
  List<Transaction> get paidFixedBillsThisMonth => _paidFixedBillsThisMonth;
  double get totalAllocatedSavings => _totalAllocatedSavings;
  String? get errorMessage => _errorMessage;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// Only counts enabled bills that have an amount set
  double get pendingFixedBillsTotal {
    double total = 0.0;
    for (final cat in _fixedBillCategories) {
      if (cat.enabled && cat.expectedMonthlyAmount != null) {
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
    final result = monthlyIncome -
        paidFixedBillsTotal -
        pendingFixedBillsTotal -
        _totalAllocatedSavings;
    return result.clamp(0.0, double.infinity);
  }

  Future<void> loadDashboardData() async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String();

      final txnMaps = await db.rawQuery('''
        SELECT t.*, c.name as category_name, c.type as category_type
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        ORDER BY t.date_paid DESC, t.id DESC
        LIMIT 5
      ''');
      _recentTransactions = txnMaps.map((m) => Transaction.fromMap(m)).toList();

      // Only enabled fixed bills
      final catMaps = await db.query('categories',
          where: 'type = ? AND enabled = 1',
          whereArgs: ['fixed_bill']);
      _fixedBillCategories = catMaps.map((m) => Category.fromMap(m)).toList();

      final paidMaps = await db.rawQuery('''
        SELECT t.*, c.name as category_name, c.type as category_type
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE c.type = 'fixed_bill'
          AND t.date_paid >= ? AND t.date_paid <= ?
      ''', [monthStart, monthEnd]);
      _paidFixedBillsThisMonth = paidMaps.map((m) => Transaction.fromMap(m)).toList();

      final savingsResult =
          await db.rawQuery('SELECT SUM(current_amount) as total FROM savings_goals');
      _totalAllocatedSavings = (savingsResult.first['total'] as num?)?.toDouble() ?? 0.0;

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
}