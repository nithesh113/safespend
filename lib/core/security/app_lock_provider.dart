import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:safespend/core/database/database_service.dart';

class AppLockProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _enabled = false;
  bool _loaded = false;

  bool get enabled => _enabled;
  bool get loaded => _loaded;

  Future<void> load() async {
    final value = await _db.getSetting('app_lock_enabled');
    final pinHash = await _db.getSetting('app_lock_pin_hash');
    _enabled = value == '1' && pinHash != null && pinHash.isNotEmpty;
    _loaded = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _db.getSetting('app_lock_pin_hash');
    if (stored == null || stored.isEmpty) return false;
    return _hash(pin) == stored;
  }

  Future<void> setPin(String pin) async {
    await _db.setSetting('app_lock_pin_hash', _hash(pin));
    await _db.setSetting('app_lock_enabled', '1');
    _enabled = true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> disable() async {
    await _db.setSetting('app_lock_enabled', '0');
    _enabled = false;
    notifyListeners();
  }

  Future<bool> authenticateWithDevice() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Unlock SafeSpend to view your finances',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}
