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

  /// Returns the database instance. On first call, initializes the DB.
  /// Never returns null — throws [DatabaseException] on failure.
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
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppDatabaseException(
        userMessage:
            'Could not initialize storage. Check that the app has storage permissions.',
        developerMessage: '_initDatabase failed',
        originalError: e,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (e) {
      // Non-fatal: FKs won't be enforced but the app still works.
      debugPrint('Warning: Failed to enable foreign keys: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('fixed_bill', 'variable_expense')),
          expected_monthly_amount REAL
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

      // Seed data — wrapped in individual try-catch so one failure
      // doesn't block the rest
      for (final seed in _seedData) {
        try {
          await db.execute(seed);
        } catch (e) {
          debugPrint('Warning: Failed to seed a category: $e');
        }
      }
    } catch (e) {
      throw AppDatabaseException(
        userMessage:
            'Failed to set up the database schema. Try reinstalling the app.',
        developerMessage: '_onCreate failed',
        originalError: e,
      );
    }
  }

  static const _seedData = [
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Rent', 'fixed_bill', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Water', 'fixed_bill', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Electricity', 'fixed_bill', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('WiFi', 'fixed_bill', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Groceries', 'variable_expense', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Transit', 'variable_expense', NULL)",
    "INSERT INTO categories (name, type, expected_monthly_amount) VALUES ('Dining', 'variable_expense', NULL)",
  ];

  /// Helper to reset the DB (for development / troubleshooting).
  Future<void> resetDatabase() async {
    try {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String path = join(documentsDir.path, 'safespend.db');
      await deleteDatabase(path);
      _database = null;
    } catch (e) {
      throw AppDatabaseException(
        userMessage: 'Failed to reset the database.',
        developerMessage: 'resetDatabase failed',
        originalError: e,
      );
    }
  }
}