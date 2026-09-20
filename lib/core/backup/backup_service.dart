import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:safespend/core/database/database_service.dart';
import 'package:safespend/core/utils/app_exception.dart';

class BackupService {
  BackupService._();

  static final instance = BackupService._();

  static const _magic = 'SAFESPEND_BACKUP';
  static const _formatVersion = 1;
  static const _iterations = 120000;

  final DatabaseService _database = DatabaseService();
  final _aes = AesGcm.with256bits();
  final _random = Random.secure();

  Future<List<int>> exportEncrypted(String password) async {
    _validatePassword(password);
    final db = await _database.database;
    final snapshot = <String, dynamic>{
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': {
        'settings': await db.query('settings'),
        'categories': await db.query('categories'),
        'transactions': await db.query('transactions'),
        'savings_goals': await db.query('savings_goals'),
        'savings_contributions': await db.query('savings_contributions'),
      },
    };

    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(snapshot)),
      secretKey: key,
      nonce: nonce,
    );
    final envelope = {
      'magic': _magic,
      'formatVersion': _formatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return utf8.encode(jsonEncode(envelope));
  }

  Future<BackupData> decryptBackup(List<int> bytes, String password) async {
    _validatePassword(password);
    try {
      final envelope = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)),
      );
      if (envelope['magic'] != _magic ||
          envelope['formatVersion'] != _formatVersion ||
          envelope['kdf'] != 'PBKDF2-HMAC-SHA256') {
        throw const FormatException('Unsupported backup format');
      }
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final cipherText = base64Decode(envelope['cipherText'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      final key = await _deriveKey(password, salt);
      final clearText = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      final snapshot = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(clearText)),
      );
      _validateSnapshot(snapshot);
      return BackupData(snapshot);
    } catch (error, stackTrace) {
      debugPrint('Could not decrypt backup: $error\n$stackTrace');
      if (error is AppException) rethrow;
      throw AppException(
        'This backup password is incorrect or the file is corrupted.',
        developerMessage: 'decryptBackup',
        originalError: error,
      );
    }
  }

  Future<void> replace(BackupData backup) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('savings_contributions');
      await txn.delete('transactions');
      await txn.delete('savings_goals');
      await txn.delete('categories');
      await txn.delete('settings');

      for (final row in backup.settings) {
        await txn.insert('settings', _settingRow(row));
      }
      for (final row in backup.categories) {
        await txn.insert('categories', _categoryRow(row));
      }
      for (final row in backup.goals) {
        await txn.insert('savings_goals', _goalRow(row));
      }
      for (final row in backup.transactions) {
        await txn.insert('transactions', _transactionRow(row));
      }
      for (final row in backup.contributions) {
        await txn.insert('savings_contributions', _contributionRow(row));
      }
    });
  }

  Future<void> merge(BackupData backup) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final categoryRows = await txn.query('categories');
      final categoryByKey = <String, Map<String, Object?>>{
        for (final row in categoryRows)
          _categoryKey(row): Map<String, Object?>.from(row),
      };
      final categoryIdMap = <int, int>{};
      for (final row in backup.categories) {
        final oldId = _int(row['id']);
        final existing = categoryByKey[_categoryKey(row)];
        if (existing != null) {
          if (oldId != null) categoryIdMap[oldId] = _int(existing['id'])!;
        } else {
          final newId = await txn.insert(
            'categories',
            _categoryRow(row, includeId: false),
          );
          if (oldId != null) categoryIdMap[oldId] = newId;
        }
      }

      final settingKeys = (await txn.query(
        'settings',
      )).map((row) => row['key'] as String).toSet();
      for (final row in backup.settings) {
        final key = row['key'] as String;
        if (!settingKeys.contains(key)) {
          await txn.insert('settings', _settingRow(row));
        }
      }

      final goalRows = await txn.query('savings_goals');
      final goalById = <int, Map<String, Object?>>{
        for (final row in goalRows)
          if (_int(row['id']) != null)
            _int(row['id'])!: Map<String, Object?>.from(row),
      };
      final goalIdMap = <int, int>{};
      for (final row in backup.goals) {
        final oldId = _int(row['id']);
        final existing = oldId == null ? null : goalById[oldId];
        if (existing != null && _sameGoal(existing, row)) {
          goalIdMap[oldId!] = oldId;
        } else {
          final newId = await txn.insert(
            'savings_goals',
            _goalRow(row, includeId: false),
          );
          if (oldId != null) goalIdMap[oldId] = newId;
        }
      }

      final transactionRows = await txn.query('transactions');
      final transactionById = <int, Map<String, Object?>>{
        for (final row in transactionRows)
          if (_int(row['id']) != null)
            _int(row['id'])!: Map<String, Object?>.from(row),
      };
      for (final row in backup.transactions) {
        final mappedCategoryId = categoryIdMap[_int(row['category_id'])];
        if (mappedCategoryId == null) continue;
        final normalized = _transactionRow(row, includeId: false)
          ..['category_id'] = mappedCategoryId;
        final oldId = _int(row['id']);
        final existing = oldId == null ? null : transactionById[oldId];
        if (existing != null && _sameTransaction(existing, normalized)) {
          continue;
        }
        if (oldId != null && existing == null) normalized['id'] = oldId;
        await txn.insert('transactions', normalized);
      }

      final contributionRows = await txn.query('savings_contributions');
      final contributionById = <int, Map<String, Object?>>{
        for (final row in contributionRows)
          if (_int(row['id']) != null)
            _int(row['id'])!: Map<String, Object?>.from(row),
      };
      for (final row in backup.contributions) {
        final mappedGoalId = goalIdMap[_int(row['goal_id'])];
        if (mappedGoalId == null) continue;
        final normalized = _contributionRow(row, includeId: false)
          ..['goal_id'] = mappedGoalId;
        final oldId = _int(row['id']);
        final existing = oldId == null ? null : contributionById[oldId];
        if (existing != null && _sameContribution(existing, normalized)) {
          continue;
        }
        if (oldId != null && existing == null) normalized['id'] = oldId;
        await txn.insert('savings_contributions', normalized);
      }
    });
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  void _validatePassword(String password) {
    if (password.trim().length < 6) {
      throw const AppException(
        'Use a backup password with at least 6 characters.',
      );
    }
  }

  void _validateSnapshot(Map<String, dynamic> snapshot) {
    final tables = snapshot['tables'];
    if (snapshot['formatVersion'] != _formatVersion || tables is! Map) {
      throw const FormatException('Invalid backup snapshot');
    }
    for (final table in [
      'settings',
      'categories',
      'transactions',
      'savings_goals',
      'savings_contributions',
    ]) {
      if (tables[table] is! List) {
        throw const FormatException('Backup table is missing');
      }
    }
  }

  String _categoryKey(Map row) =>
      '${row['type']}|${(row['name'] as String).trim().toLowerCase()}';

  Map<String, Object?> _settingRow(Map row) => {
    'key': row['key'],
    'value': row['value'],
  };

  Map<String, Object?> _categoryRow(Map row, {bool includeId = true}) => {
    if (includeId && row['id'] != null) 'id': _int(row['id']),
    'name': row['name'],
    'type': row['type'],
    'expected_monthly_amount': row['expected_monthly_amount'],
    'due_day': _int(row['due_day']) ?? 1,
    'enabled': _int(row['enabled']) ?? 1,
    'archived': _int(row['archived']) ?? 0,
    'reminder_enabled': _int(row['reminder_enabled']) ?? 1,
  };

  Map<String, Object?> _goalRow(Map row, {bool includeId = true}) => {
    if (includeId && row['id'] != null) 'id': _int(row['id']),
    'title': row['title'],
    'target_amount': row['target_amount'],
    'current_amount': row['current_amount'],
    'monthly_contribution': row['monthly_contribution'] ?? 0,
    'target_date': row['target_date'],
  };

  Map<String, Object?> _transactionRow(Map row, {bool includeId = true}) => {
    if (includeId && row['id'] != null) 'id': _int(row['id']),
    'category_id': _int(row['category_id']),
    'amount': row['amount'],
    'date_paid': row['date_paid'],
    'note': row['note'],
  };

  Map<String, Object?> _contributionRow(Map row, {bool includeId = true}) => {
    if (includeId && row['id'] != null) 'id': _int(row['id']),
    'goal_id': _int(row['goal_id']),
    'amount': row['amount'],
    'contributed_at': row['contributed_at'],
    'note': row['note'],
  };

  int? _int(Object? value) => (value as num?)?.toInt();

  bool _sameGoal(Map existing, Map incoming) =>
      existing['title'] == incoming['title'] &&
      existing['target_amount'] == incoming['target_amount'] &&
      existing['current_amount'] == incoming['current_amount'] &&
      (existing['monthly_contribution'] ?? 0) ==
          (incoming['monthly_contribution'] ?? 0) &&
      existing['target_date'] == incoming['target_date'];

  bool _sameTransaction(Map existing, Map incoming) =>
      existing['category_id'] == incoming['category_id'] &&
      existing['amount'] == incoming['amount'] &&
      existing['date_paid'] == incoming['date_paid'] &&
      existing['note'] == incoming['note'];

  bool _sameContribution(Map existing, Map incoming) =>
      existing['goal_id'] == incoming['goal_id'] &&
      existing['amount'] == incoming['amount'] &&
      existing['contributed_at'] == incoming['contributed_at'] &&
      existing['note'] == incoming['note'];
}

class BackupData {
  BackupData(Map<String, dynamic> snapshot) : _snapshot = snapshot;

  final Map<String, dynamic> _snapshot;

  String get exportedAt => _snapshot['exportedAt'] as String;

  List<Map<String, dynamic>> get settings => _rows('settings');
  List<Map<String, dynamic>> get categories => _rows('categories');
  List<Map<String, dynamic>> get transactions => _rows('transactions');
  List<Map<String, dynamic>> get goals => _rows('savings_goals');
  List<Map<String, dynamic>> get contributions =>
      _rows('savings_contributions');

  List<Map<String, dynamic>> _rows(String table) =>
      ((Map<String, dynamic>.from(_snapshot['tables'] as Map))[table] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  String get formattedExportDate {
    final date = DateTime.tryParse(exportedAt)?.toLocal();
    return date == null
        ? exportedAt
        : DateFormat('MMM d, yyyy h:mm a').format(date);
  }
}
