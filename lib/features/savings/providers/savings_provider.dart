import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';
import 'package:safespend/shared/models/savings_goal.dart';

class SavingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<SavingsGoal> _goals = [];
  String? _errorMessage;

  List<SavingsGoal> get goals => _goals;
  String? get errorMessage => _errorMessage;

  Future<void> loadGoals() async {
    try {
      final db = await _db.database;
      final maps = await db.query('savings_goals', orderBy: 'id DESC');
      _goals = maps.map((m) => SavingsGoal.fromMap(m)).toList();
      _errorMessage = null;
      notifyListeners();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error loading savings goals: $e\n$stackTrace');
      _errorMessage = 'Could not load savings goals. Pull down to retry.';
      notifyListeners();
    }
  }

  Future<SavingsGoal> createGoal({
    required String title,
    required double targetAmount,
    String? targetDate,
  }) async {
    try {
      final db = await _db.database;
      final goal = SavingsGoal(
        title: title,
        targetAmount: targetAmount,
        targetDate: targetDate,
      );
      final id = await db.insert('savings_goals', goal.toMap());
      final created = goal.copyWith(id: id);
      _goals.insert(0, created);
      _errorMessage = null;
      notifyListeners();
      return created;
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error creating savings goal: $e\n$stackTrace');
      throw AppException(
        'Failed to create savings goal. Please try again.',
        developerMessage: 'createGoal failed',
        originalError: e,
      );
    }
  }

  Future<void> addFunds(int goalId, double amount) async {
    try {
      final db = await _db.database;

      final results = await db.query('savings_goals',
          columns: ['current_amount'],
          where: 'id = ?',
          whereArgs: [goalId]);

      if (results.isEmpty) {
        throw AppException('Savings goal no longer exists.');
      }

      final currentAmount =
          (results.first['current_amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = currentAmount + amount;

      await db.update(
        'savings_goals',
        {'current_amount': newAmount},
        where: 'id = ?',
        whereArgs: [goalId],
      );

      // Refresh the list
      await loadGoals();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error adding funds: $e\n$stackTrace');
      throw AppException(
        'Failed to add funds. Please try again.',
        developerMessage: 'addFunds failed',
        originalError: e,
      );
    }
  }

  Future<void> deleteGoal(int goalId) async {
    try {
      final db = await _db.database;
      await db.delete('savings_goals', where: 'id = ?', whereArgs: [goalId]);
      await loadGoals();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('Error deleting goal: $e\n$stackTrace');
      throw AppException(
        'Failed to delete goal. Please try again.',
        developerMessage: 'deleteGoal failed',
        originalError: e,
      );
    }
  }
}