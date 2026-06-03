import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const _pinKey = 'docvault_pin';
  static const _bioEnabledKey = 'docvault_use_biometrics';
  static const _autoLockKey = 'docvault_auto_lock_duration';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
    ),
  );
  static final _auth = LocalAuthentication();

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored == pin;
  }

  static Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
  }

  // ── Biometrics ──────────────────────────────────────────────────────────

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _bioEnabledKey);
    return val == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _bioEnabledKey, value: enabled.toString());
  }

  static Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open DocVault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  // ── Auto Lock ───────────────────────────────────────────────────────────

  static Future<int> getAutoLockDuration() async {
    final val = await _storage.read(key: _autoLockKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  static Future<void> setAutoLockDuration(int seconds) async {
    await _storage.write(key: _autoLockKey, value: seconds.toString());
  }
}
