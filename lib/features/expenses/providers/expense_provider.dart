import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/shared/models/transaction.dart';
import 'package:safespend/shared/models/category.dart';
import 'package:intl/intl.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Category> _categories = [];
  String? _errorMessage;

  List<Category> get categories => _categories;
  String? get errorMessage => _errorMessage;
  List<Category> get variableExpenseCategories =>
      _categories.where((c) => c.type == 'variable_expense').toList();
  List<Category> get fixedBillCategories =>
      _categories.where((c) => c.type == 'fixed_bill').toList();

  Future<void> loadCategories() async {
    try {
      final db = await _db.database;
      final maps = await db.query('categories', orderBy: 'type, name');
      _categories = maps.map((m) => Category.fromMap(m)).toList();
      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error loading categories: $e\n$stackTrace');
      _errorMessage = 'Could not load categories. Pull down to retry.';
      notifyListeners();
    }
  }

  /// Insert a new transaction. Returns the created [Transaction] on success.
  /// Throws [AppException] with a user-friendly message on failure.
  Future<Transaction> addTransaction({
    required int categoryId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    try {
      final db = await _db.database;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final txn = Transaction(
        categoryId: categoryId,
        amount: amount,
        datePaid: dateStr,
        note: note,
      );

      final id = await db.insert('transactions', txn.toMap());
      return txn.copyWith(id: id);
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error adding transaction: $e\n$stackTrace');
      throw AppException(
        'Failed to save transaction. Please try again.',
        developerMessage: 'addTransaction failed',
        originalError: e,
      );
    }
  }

  /// Check if a fixed bill has been paid this month.
  Future<bool> isFixedBillPaidThisMonth(int categoryId) async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      final monthStart =
          DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      final monthEnd =
          DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));

      final result = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM transactions
        WHERE category_id = ? AND date_paid >= ? AND date_paid <= ?
      ''', [categoryId, monthStart, monthEnd]);

      final count = result.first['cnt'] as int;
      return count > 0;
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error checking bill status: $e\n$stackTrace');
      // On error, default to false rather than crashing
      return false;
    }
  }
}