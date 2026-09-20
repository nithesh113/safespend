import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/notifications/bill_notification_service.dart';
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

  List<Category> get fixedBillCategories => _allCategories
      .where((c) => c.type == 'fixed_bill' && !c.archived)
      .toList();

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
      await _syncBillNotifications();

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
      throw AppException(
        'Failed to save income.',
        developerMessage: 'setMonthlyIncome',
        originalError: e,
      );
    }
  }

  Future<void> setCategoryAmount(int categoryId, double amount) async {
    try {
      await _db.updateCategoryAmount(categoryId, amount);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(
          expectedMonthlyAmount: amount,
        );
      }
      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error updating category: $e\n$stackTrace');
      throw AppException(
        'Failed to update amount.',
        developerMessage: 'setCategoryAmount',
        originalError: e,
      );
    }
  }

  Future<void> setCategoryDueDay(int categoryId, int dueDay) async {
    try {
      await _db.updateCategoryDueDay(categoryId, dueDay);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(dueDay: dueDay);
      }
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error updating bill due day: $e\n$stackTrace');
      throw AppException(
        'Failed to update due date.',
        developerMessage: 'setCategoryDueDay',
        originalError: e,
      );
    }
  }

  Future<Category> createRecurringBill({
    required String name,
    required double amount,
    required int dueDay,
  }) async {
    try {
      final id = await _db.createRecurringBill(
        name: name,
        amount: amount,
        dueDay: dueDay,
      );
      final category = Category(
        id: id,
        name: name,
        type: 'fixed_bill',
        expectedMonthlyAmount: amount,
        dueDay: dueDay,
      );
      _allCategories = [..._allCategories, category]
        ..sort((a, b) => a.name.compareTo(b.name));
      await _syncBillNotifications();
      notifyListeners();
      return category;
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error creating recurring bill: $e\n$stackTrace');
      throw AppException(
        'Failed to create recurring bill.',
        developerMessage: 'createRecurringBill',
        originalError: e,
      );
    }
  }

  Future<void> deleteRecurringBill(int categoryId) async {
    try {
      await BillNotificationService.instance.cancelBill(categoryId);
      await _db.deleteCategory(categoryId);
      _allCategories = _allCategories.where((c) => c.id != categoryId).toList();
      await _syncBillNotifications();
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error deleting recurring bill: $e\n$stackTrace');
      throw AppException(
        'Failed to delete recurring bill.',
        developerMessage: 'deleteRecurringBill',
        originalError: e,
      );
    }
  }

  Future<void> toggleCategory(int categoryId, bool enabled) async {
    try {
      await _db.toggleCategoryEnabled(categoryId, enabled);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(enabled: enabled);
      }
      await _syncBillNotifications();
      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error toggling category: $e\n$stackTrace');
      throw AppException(
        'Failed to toggle bill.',
        developerMessage: 'toggleCategory',
        originalError: e,
      );
    }
  }

  Future<void> toggleCategoryReminder(int categoryId, bool enabled) async {
    try {
      await _db.toggleCategoryReminder(categoryId, enabled);
      final idx = _allCategories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) {
        _allCategories[idx] = _allCategories[idx].copyWith(
          reminderEnabled: enabled,
        );
      }
      await _syncBillNotifications();
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error toggling bill reminder: $e\n$stackTrace');
      throw AppException(
        'Failed to update bill reminder.',
        developerMessage: 'toggleCategoryReminder',
        originalError: e,
      );
    }
  }

  Future<void> _syncBillNotifications() async {
    try {
      await BillNotificationService.instance.syncBills(_allCategories);
    } catch (e, stackTrace) {
      debugPrint('Error syncing bill notifications: $e\n$stackTrace');
    }
  }
}
