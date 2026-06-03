import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const _pinKey = 'docvault_pin';
  static const _bioEnabledKey = 'docvault_use_biometrics';
  static const _autoLockKey = 'docvault_auto_lock_duration';
  static const _failedAttemptsKey = 'docvault_failed_attempts';
  static const _lockoutUntilKey = 'docvault_lockout_until';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
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
    final ok = stored == pin;
    if (ok) {
      await resetFailedAttempts();
    } else {
      await incrementFailedAttempts();
    }
    return ok;
  }

  static Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await resetFailedAttempts();
  }

  // ── Lockout ─────────────────────────────────────────────────────────────

  static Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  static Future<void> incrementFailedAttempts() async {
    final count = await getFailedAttempts() + 1;
    await _storage.write(key: _failedAttemptsKey, value: count.toString());

    if (count >= 5) {
      int seconds = 30;
      if (count == 6) seconds = 60;
      if (count == 7) seconds = 300;
      if (count >= 8) seconds = 1800;

      final until = DateTime.now().add(Duration(seconds: seconds));
      await _storage.write(key: _lockoutUntilKey, value: until.toIso8601String());
    }
  }

  static Future<void> resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  static Future<DateTime?> getLockoutUntil() async {
    final val = await _storage.read(key: _lockoutUntilKey);
    if (val == null) return null;
    final until = DateTime.tryParse(val);
    if (until == null) return null;
    if (until.isBefore(DateTime.now())) {
      // Don't reset failed attempts here, only on successful login
      return null;
    }
    return until;
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
