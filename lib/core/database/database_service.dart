import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safespend/core/utils/app_exception.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppDatabaseException(
        userMessage: 'Failed to open the database. Please restart the app.',
        developerMessage: 'DB initialization failed',
        originalError: e,
      );
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String path = join(documentsDir.path, 'safespend.db');
      return await openDatabase(
        path,
        version: 2,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppDatabaseException(
        userMessage: 'Could not initialize storage.',
        developerMessage: '_initDatabase failed',
        originalError: e,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (e) {
      debugPrint('Warning: Failed to enable foreign keys: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      // Default income
      await db.insert('settings', {'key': 'monthly_income', 'value': '350000'});

      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('fixed_bill', 'variable_expense')),
          expected_monthly_amount REAL,
          enabled INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          date_paid TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (category_id) REFERENCES categories(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE savings_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          target_amount REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0.0,
          target_date TEXT
        )
      ''');

      for (final seed in _seedData) {
        try {
          await db.execute(seed);
        } catch (e) {
          debugPrint('Warning: Failed to seed category: $e');
        }
      }
    } catch (e) {
      throw AppDatabaseException(
        userMessage: 'Failed to set up database. Try reinstalling the app.',
        developerMessage: '_onCreate failed',
        originalError: e,
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        // Insert default income only if not exists
        final existing =
            await db.query('settings', where: 'key = ?', whereArgs: ['monthly_income']);
        if (existing.isEmpty) {
          await db.insert('settings', {'key': 'monthly_income', 'value': '350000'});
        }
        // Add enabled column
        try {
          await db.execute('ALTER TABLE categories ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1');
        } catch (_) {}
      } catch (e) {
        debugPrint('Migration warning: $e');
      }
    }
  }

  // --- Settings CRUD ---
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result =
        await db.query('settings', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Category CRUD ---
  Future<void> updateCategoryAmount(int id, double amount) async {
    final db = await database;
    await db.update('categories', {'expected_monthly_amount': amount},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleCategoryEnabled(int id, bool enabled) async {
    final db = await database;
    await db.update('categories', {'enabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static const _seedData = [
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Rent', 'fixed_bill', 0, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Water', 'fixed_bill', 0, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Electricity', 'fixed_bill', 0, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('WiFi', 'fixed_bill', 0, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Groceries', 'variable_expense', NULL, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Transit', 'variable_expense', NULL, 1)",
    "INSERT INTO categories (name, type, expected_monthly_amount, enabled) VALUES ('Dining', 'variable_expense', NULL, 1)",
  ];

  Future<void> resetDatabase() async {
    try {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String path = join(documentsDir.path, 'safespend.db');
      await deleteDatabase(path);
      _database = null;
    } catch (e) {
      throw AppDatabaseException(
        userMessage: 'Failed to reset database.',
        developerMessage: 'resetDatabase failed',
        originalError: e,
      );
    }
  }
}