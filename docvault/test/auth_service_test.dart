// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docvault/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Fake storage — stores everything in an in-memory map.
// Avoids any real Android Keystore / platform channel involvement.
// ---------------------------------------------------------------------------

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.remove(key);

  void clear() => _store.clear();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    AuthService.overrideStorageForTesting(fakeStorage);
  });

  tearDown(() => fakeStorage.clear());

  // ── hasPin ────────────────────────────────────────────────────────────────

  group('hasPin', () {
    test('returns false when no PIN has been set', () async {
      expect(await AuthService.hasPin(), isFalse);
    });

    test('returns true after setPin()', () async {
      await AuthService.setPin('1234');
      expect(await AuthService.hasPin(), isTrue);
    });

    test('returns false after removePin()', () async {
      await AuthService.setPin('1234');
      await AuthService.removePin();
      expect(await AuthService.hasPin(), isFalse);
    });
  });

  // ── PIN hashing ───────────────────────────────────────────────────────────

  group('PIN hashing', () {
    test('stored value is a 64-character hex string, not the raw PIN', () async {
      await AuthService.setPin('9999');
      // Read directly from the fake store to inspect what was persisted.
      final stored = await fakeStorage.read(key: 'docvault_pin');
      expect(stored, isNotNull);
      expect(stored!.length, equals(64),
          reason: 'SHA-256 hex digest must be 64 characters');
      expect(stored, isNot(equals('9999')),
          reason: 'PIN must be stored hashed, never plain-text');
    });

    test('same PIN produces DIFFERENT hashes when set twice (Dynamic Salting)', () async {
      await AuthService.setPin('0000');
      final first = await fakeStorage.read(key: 'docvault_pin');
      fakeStorage.clear();
      await AuthService.setPin('0000');
      final second = await fakeStorage.read(key: 'docvault_pin');
      expect(first, isNot(equals(second)), 
          reason: 'Dynamic salting ensures same PIN gets unique hash every time');
    });

    test('different PINs produce different hashes', () async {
      await AuthService.setPin('1111');
      final hash1 = await fakeStorage.read(key: 'docvault_pin');
      fakeStorage.clear();
      await AuthService.setPin('2222');
      final hash2 = await fakeStorage.read(key: 'docvault_pin');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  // ── verifyPin ────────────────────────────────────────────────────────────

  group('verifyPin', () {
    test('returns true for the correct PIN', () async {
      await AuthService.setPin('4321');
      expect(await AuthService.verifyPin('4321'), isTrue);
    });

    test('returns false for a wrong PIN', () async {
      await AuthService.setPin('4321');
      expect(await AuthService.verifyPin('1234'), isFalse);
    });

    test('returns false when no PIN is set', () async {
      expect(await AuthService.verifyPin('0000'), isFalse);
    });

    test('successful verify resets failed attempt counter', () async {
      await AuthService.setPin('5678');
      // Simulate two failures first.
      await AuthService.verifyPin('0000');
      await AuthService.verifyPin('0000');
      expect(await AuthService.getFailedAttempts(), equals(2));

      // Correct PIN — counter should reset.
      await AuthService.verifyPin('5678');
      expect(await AuthService.getFailedAttempts(), equals(0));
    });

    // Plain-text migration path: if the stored value is shorter than 64 chars
    // it is treated as a legacy plain-text PIN and migrated to a hash.
    test('migrates a legacy plain-text PIN to hashed on successful verify',
        () async {
      // Write a plain-text PIN directly (simulating a pre-hash database row).
      await fakeStorage.write(key: 'docvault_pin', value: '3333');

      final result = await AuthService.verifyPin('3333');
      expect(result, isTrue, reason: 'Legacy plain-text PIN must still verify');

      final stored = await fakeStorage.read(key: 'docvault_pin');
      expect(stored!.length, equals(64),
          reason: 'After migration the PIN must be stored as a SHA-256 hash');
    });
  });

  // ── Lockout escalation ────────────────────────────────────────────────────

  group('lockout escalation', () {
    test('no lockout after fewer than 5 failed attempts', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 4; i++) {
        await AuthService.verifyPin('0000');
      }
      expect(await AuthService.getLockoutUntil(), isNull);
    });

    test('lockout is set after exactly 5 failed attempts', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 5; i++) {
        await AuthService.verifyPin('0000');
      }
      final lockoutUntil = await AuthService.getLockoutUntil();
      expect(lockoutUntil, isNotNull,
          reason: 'A lockout timestamp must be written after 5 failures');
      expect(lockoutUntil!.isAfter(DateTime.now()), isTrue);
    });

    test('lockout at 5 attempts is ~30 seconds', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 5; i++) {
        await AuthService.verifyPin('0000');
      }
      final lockoutUntil = await AuthService.getLockoutUntil();
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      // Allow a ±2s window for test execution time.
      expect(remaining, greaterThanOrEqualTo(28));
      expect(remaining, lessThanOrEqualTo(32));
    });

    test('lockout escalates to ~60 s after 6 failures', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 6; i++) {
        await AuthService.verifyPin('0000');
      }
      final lockoutUntil = await AuthService.getLockoutUntil();
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      expect(remaining, greaterThanOrEqualTo(58));
      expect(remaining, lessThanOrEqualTo(62));
    });

    test('lockout escalates to ~5 min (300 s) after 7 failures', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 7; i++) {
        await AuthService.verifyPin('0000');
      }
      final lockoutUntil = await AuthService.getLockoutUntil();
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      expect(remaining, greaterThanOrEqualTo(298));
      expect(remaining, lessThanOrEqualTo(302));
    });

    test('lockout escalates to ~30 min (1800 s) after 8+ failures', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 8; i++) {
        await AuthService.verifyPin('0000');
      }
      final lockoutUntil = await AuthService.getLockoutUntil();
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      expect(remaining, greaterThanOrEqualTo(1798));
      expect(remaining, lessThanOrEqualTo(1802));
    });

    test('getLockoutUntil returns null for an expired lockout timestamp',
        () async {
      // Write a lockout timestamp in the past directly.
      final past =
          DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String();
      await fakeStorage.write(key: 'docvault_lockout_until', value: past);

      expect(await AuthService.getLockoutUntil(), isNull);
    });

    test('resetFailedAttempts clears counter and lockout', () async {
      await AuthService.setPin('1111');
      for (var i = 0; i < 5; i++) {
        await AuthService.verifyPin('0000');
      }
      expect(await AuthService.getLockoutUntil(), isNotNull);

      await AuthService.resetFailedAttempts();
      expect(await AuthService.getFailedAttempts(), equals(0));
      expect(await AuthService.getLockoutUntil(), isNull);
    });
  });

  // ── Auto-lock duration ────────────────────────────────────────────────────

  group('autoLockDuration', () {
    test('defaults to 0 (Immediately) when nothing is stored', () async {
      expect(await AuthService.getAutoLockDuration(), equals(0));
    });

    test('persists the value set by setAutoLockDuration', () async {
      await AuthService.setAutoLockDuration(300);
      expect(await AuthService.getAutoLockDuration(), equals(300));
    });

    test('can be updated', () async {
      await AuthService.setAutoLockDuration(60);
      await AuthService.setAutoLockDuration(600);
      expect(await AuthService.getAutoLockDuration(), equals(600));
    });
  });

  // ── Biometric flag ────────────────────────────────────────────────────────

  group('biometricEnabled', () {
    test('defaults to false when nothing is stored', () async {
      expect(await AuthService.isBiometricEnabled(), isFalse);
    });

    test('is true after setBiometricEnabled(true)', () async {
      await AuthService.setBiometricEnabled(true);
      expect(await AuthService.isBiometricEnabled(), isTrue);
    });

    test('is false after setBiometricEnabled(false)', () async {
      await AuthService.setBiometricEnabled(true);
      await AuthService.setBiometricEnabled(false);
      expect(await AuthService.isBiometricEnabled(), isFalse);
    });
  });
}
