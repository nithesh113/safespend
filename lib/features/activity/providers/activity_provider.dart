import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/shared/models/transaction.dart';

class ActivityProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _loading = true;
  String? _errorMessage;
  List<Transaction> _transactions = [];
  Map<String, double> _categoryTotals = {};
  Map<int, double> _dailyTotals = {};
  double _variableExpenses = 0;
  double _paidBills = 0;
  double _savingsContributions = 0;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  List<Transaction> get transactions => _transactions;
  Map<String, double> get categoryTotals => _categoryTotals;
  Map<int, double> get dailyTotals => _dailyTotals;
  double get variableExpenses => _variableExpenses;
  double get paidBills => _paidBills;
  double get totalSpent => _variableExpenses + _paidBills;
  double get savingsContributions => _savingsContributions;

  DateTime get selectedMonth => _selectedMonth;
  String get monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);
  bool get isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  int get daysInSelectedMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

  Future<void> load({DateTime? month}) async {
    if (month != null) {
      _selectedMonth = DateTime(month.year, month.month);
    }
    _loading = true;
    notifyListeners();
    try {
      final db = await _db.database;
      final start = _dateString(
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      );
      final end = _dateString(
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      );
      final maps = await db.rawQuery(
        '''
        SELECT t.*, c.name as category_name, c.type as category_type
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.date_paid >= ? AND t.date_paid <= ?
        ORDER BY t.date_paid DESC, t.id DESC
        ''',
        [start, end],
      );
      _transactions = maps.map((map) => Transaction.fromMap(map)).toList();

      final categories = <String, double>{};
      final days = <int, double>{};
      var variable = 0.0;
      var bills = 0.0;
      for (final transaction in _transactions) {
        final name = transaction.categoryName ?? 'Other';
        categories[name] = (categories[name] ?? 0) + transaction.amount;
        final date = DateTime.tryParse(transaction.datePaid);
        if (date != null) {
          days[date.day] = (days[date.day] ?? 0) + transaction.amount;
        }
        if (transaction.categoryType == 'fixed_bill') {
          bills += transaction.amount;
        } else {
          variable += transaction.amount;
        }
      }
      final savingsResult = await db.rawQuery(
        '''
        SELECT SUM(amount) as total
        FROM savings_contributions
        WHERE contributed_at >= ? AND contributed_at <= ?
        ''',
        [start, end],
      );

      _categoryTotals = categories;
      _dailyTotals = days;
      _variableExpenses = variable;
      _paidBills = bills;
      _savingsContributions =
          (savingsResult.first['total'] as num?)?.toDouble() ?? 0;
      _errorMessage = null;
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Error loading activity: $error\n$stackTrace');
      _errorMessage = 'Could not load activity data. Pull down to retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _dateString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
