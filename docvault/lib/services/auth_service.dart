import 'dart:convert';
import 'package:crypto/crypto.dart';
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
      resetOnError: false,
    ),
  );
  static final _auth = LocalAuthentication();

  static String _hashPin(String pin) {
    // Basic hash with a static salt for the PIN.
    final bytes = utf8.encode('docvault_salt_\$pin');
    return sha256.convert(bytes).toString();
  }

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final hashed = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hashed);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;

    // Check if the stored PIN is plain-text (migration fallback)
    // A SHA256 hash is 64 characters long in hex. If it's short, it's probably the old plain PIN.
    bool ok = false;
    if (stored.length < 64) {
      ok = stored == pin;
      if (ok) {
        // Migrate to hashed PIN
        await setPin(pin);
      }
    } else {
      // Constant-time comparison for the hash to prevent timing attacks.
      final hashedPin = _hashPin(pin);
      ok = _constantTimeEquals(stored, hashedPin);
    }

    if (ok) {
      await resetFailedAttempts();
    } else {
      await incrementFailedAttempts();
    }
    return ok;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
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
