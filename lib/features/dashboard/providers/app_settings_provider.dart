import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/shared/models/category.dart';

/// Persisted settings: income, category amounts, category toggles.
class AppSettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double _monthlyIncome = 350000;
  List<Category> _allCategories = [];
  String? _errorMessage;

  double get monthlyIncome => _monthlyIncome;
  List<Category> get allCategories => _allCategories;
  String? get errorMessage => _errorMessage;

  List<Category> get fixedBillCategories =>
      _allCategories.where((c) => c.type == 'fixed_bill').toList();

  List<Category> get variableExpenseCategories =>
      _allCategories.where((c) => c.type == 'variable_expense').toList();

  Future<void> loadAll() async {
    try {
      final db = await _db.database;

      // Income
      final incomeStr = await _db.getSetting('monthly_income');
      _monthlyIncome = double.tryParse(incomeStr ?? '350000') ?? 350000;

      // Categories
      final maps = await db.query('categories', orderBy: 'type, name');
      _allCategories = maps.map((m) => Category.fromMap(m)).toList();

      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error loading settings: $e\n$stackTrace');
      _errorMessage = 'Could not load settings. Pull down to retry.';
      notifyListeners();
    }
  }

  Future<void> setMonthlyIncome(double amount) async {
    try {
      await _db.setSetting('monthly_income', amount.toStringAsFixed(0));
      _monthlyIncome = amount;
      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error saving income: $e\n$stackTrace');
      throw AppException('Failed to save income.', developerMessage: 'setMonthlyIncome', originalError: e);
    }
  }

  Future<void> setCategoryAmount(int categoryId, double amount) async {
    try {
      await _db.updateCategoryAmount(categoryId, amount);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(expectedMonthlyAmount: amount);
      }
      _errorMessage = null;
      notifyListeners();
    } on AppException { rethrow; }
    catch (e, stackTrace) {
      debugPrint('Error updating category: $e\n$stackTrace');
      throw AppException('Failed to update amount.', developerMessage: 'setCategoryAmount', originalError: e);
    }
  }

  Future<void> toggleCategory(int categoryId, bool enabled) async {
    try {
      await _db.toggleCategoryEnabled(categoryId, enabled);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(enabled: enabled);
      }
      _errorMessage = null;
      notifyListeners();
    } on AppException { rethrow; }
    catch (e, stackTrace) {
      debugPrint('Error toggling category: $e\n$stackTrace');
      throw AppException('Failed to toggle bill.', developerMessage: 'toggleCategory', originalError: e);
    }
  }
}