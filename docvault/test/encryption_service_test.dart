// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';

import 'package:docvault/services/encryption_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds EncryptionService with a fixed, known key so tests are deterministic
/// and never touch the real Android Keystore / FlutterSecureStorage.
void _seedKey(enc.Key key, {enc.IV? legacyIv}) {
  EncryptionService.initForTesting(key, legacyIv: legacyIv);
  // Redirect encrypted output to system temp — no Flutter engine needed.
  EncryptionService.encDirOverride =
      Directory('${Directory.systemTemp.path}/docvault_enc_test');
}

/// Write [bytes] to a temp file and return it.
Future<File> _tmpFile(List<int> bytes) async {
  final dir = Directory.systemTemp.createTempSync('docvault_test_');
  final f = File('${dir.path}/input.bin');
  await f.writeAsBytes(bytes);
  return f;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Use a fixed 32-byte key for all tests — no device keystore involved.
  final testKey = enc.Key.fromUtf8('DocVaultTestKey!DocVaultTestKey!'); // 32 chars

  setUp(() => _seedKey(testKey));

  // After each test, wipe any .enc files created in system temp.
  tearDown(() async {
    final tmp = Directory.systemTemp;
    await for (final entity in tmp.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.enc')) {
        await entity.delete().catchError((_) => entity);
      }
    }
  });

  // ── Round-trip tests ──────────────────────────────────────────────────────

  group('encryptFile / decryptFile round-trip', () {
    test('restores original bytes for a small payload', () async {
      final original = Uint8List.fromList([1, 2, 3, 4, 5, 255, 0, 128]);
      final src = await _tmpFile(original);

      final encPath = await EncryptionService.encryptFile(src);
      final decrypted = await EncryptionService.decryptFile(encPath);

      expect(decrypted, equals(original),
          reason: 'Decrypted bytes must exactly match the original');
    });

    test('restores original bytes for a 1 MB payload', () async {
      // 1 MB of pseudo-random-ish data (incrementing bytes mod 256)
      final original = Uint8List.fromList(
          List.generate(1024 * 1024, (i) => i & 0xFF));
      final src = await _tmpFile(original);

      final encPath = await EncryptionService.encryptFile(src);
      final decrypted = await EncryptionService.decryptFile(encPath);

      expect(decrypted.length, equals(original.length));
      expect(decrypted, equals(original));
    });

    test('restores an empty file (0 bytes)', () async {
      final src = await _tmpFile([]);
      final encPath = await EncryptionService.encryptFile(src);
      final decrypted = await EncryptionService.decryptFile(encPath);
      expect(decrypted, isEmpty);
    });

    test('restores a single-byte file', () async {
      final src = await _tmpFile([0xAB]);
      final encPath = await EncryptionService.encryptFile(src);
      final decrypted = await EncryptionService.decryptFile(encPath);
      expect(decrypted, equals([0xAB]));
    });

    test('restores original bytes even if plaintext starts with DV magic header',
        () async {
      // Plaintext: [0x44, 0x56, 0x01, ...] (Matches DV magic header)
      final original = Uint8List.fromList([0x44, 0x56, 0x01, 0xAA, 0xBB]);
      final src = await _tmpFile(original);

      final encPath = await EncryptionService.encryptFile(src);
      final decrypted = await EncryptionService.decryptFile(encPath);

      expect(decrypted, equals(original),
          reason: 'Service must not be confused by magic bytes in the plaintext');
    });
  });

  // ── Legacy Support ────────────────────────────────────────────────────────

  group('legacy CBC fallback', () {
    test('successfully decrypts a file with no magic header (Legacy CBC)',
        () async {
      final plaintext = 'Legacy document content'.codeUnits;
      final key = enc.Key.fromUtf8('LegacyKeyLegacyKeyLegacyKeyLegac'); // 32 chars
      final iv = enc.IV.fromUtf8('LegacyIVLegacyIV'); // 16 chars

      // Manually create a CBC-encrypted file (simulating old app version)
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
      
      final dir = Directory.systemTemp.createTempSync('docvault_legacy_');
      final legacyFile = File('${dir.path}/legacy.enc');
      await legacyFile.writeAsBytes(encrypted.bytes);

      // Configure service with matching legacy keys
      _seedKey(key, legacyIv: iv);

      final decrypted = await EncryptionService.decryptFile(legacyFile.path);
      expect(Uint8List.fromList(decrypted), equals(plaintext),
          reason: 'Service must fall back to CBC if no magic header is present');
    });

    test('throws if legacy decryption fails (wrong key/IV for CBC)', () async {
      final dir = Directory.systemTemp.createTempSync('docvault_legacy_');
      final garbageFile = File('${dir.path}/garbage.enc');
      await garbageFile.writeAsBytes(List.generate(32, (i) => i));

      // Configure service with some legacy IV so it tries CBC
      _seedKey(testKey, legacyIv: enc.IV.fromLength(16));

      expect(
        () => EncryptionService.decryptFile(garbageFile.path),
        throwsA(anything),
        reason: 'Should throw if both GCM and CBC decryption fail',
      );
    });
  });

  // ── Ciphertext properties ─────────────────────────────────────────────────

  group('encrypted file properties', () {
    test('ciphertext is not equal to plaintext', () async {
      final original = Uint8List.fromList(List.generate(64, (i) => i));
      final src = await _tmpFile(original);

      final encPath = await EncryptionService.encryptFile(src);
      final cipherBytes = await File(encPath).readAsBytes();

      // The ciphertext must differ from the plaintext.
      expect(cipherBytes, isNot(equals(original)));
    });

    test('encrypted file starts with the DV magic header [0x44, 0x56, 0x01]',
        () async {
      final src = await _tmpFile([10, 20, 30]);
      final encPath = await EncryptionService.encryptFile(src);
      final cipherBytes = await File(encPath).readAsBytes();

      expect(cipherBytes[0], equals(0x44), reason: 'First byte must be 0x44 (D)');
      expect(cipherBytes[1], equals(0x56), reason: 'Second byte must be 0x56 (V)');
      expect(cipherBytes[2], equals(0x01), reason: 'Third byte must be 0x01 (version)');
    });

    test('two encryptions of the same plaintext produce different ciphertexts '
        '(fresh IV each time)', () async {
      final original = Uint8List.fromList(List.filled(32, 0xAA));
      final src = await _tmpFile(original);

      final path1 = await EncryptionService.encryptFile(src);
      final path2 = await EncryptionService.encryptFile(src);

      final bytes1 = await File(path1).readAsBytes();
      final bytes2 = await File(path2).readAsBytes();

      expect(bytes1, isNot(equals(bytes2)),
          reason: 'Each encryption must use a fresh random IV');
    });
  });

  // ── Wrong-key rejection ───────────────────────────────────────────────────

  group('decryption with wrong key', () {
    test('throws when decrypting with a different key', () async {
      final original = Uint8List.fromList([7, 8, 9, 10, 11, 12]);
      final src = await _tmpFile(original);

      // Encrypt with the original test key.
      final encPath = await EncryptionService.encryptFile(src);

      // Swap in a different key — decryption must fail.
      final wrongKey = enc.Key.fromUtf8('WrongKeyWrongKey!WrongKeyWrongKey');
      _seedKey(wrongKey);

      expect(
        () => EncryptionService.decryptFile(encPath),
        throwsA(anything),
        reason: 'GCM authentication tag check must reject a wrong key',
      );
    });
  });

  // ── Tamper detection (GCM authentication) ────────────────────────────────

  group('tamper detection', () {
    test('throws when a single byte in the ciphertext is flipped', () async {
      final original = Uint8List.fromList(List.generate(32, (i) => i));
      final src = await _tmpFile(original);

      final encPath = await EncryptionService.encryptFile(src);
      final cipherBytes = await File(encPath).readAsBytes();

      // Flip one byte in the ciphertext region (after 3-byte header + 12-byte IV).
      final tampered = Uint8List.fromList(cipherBytes);
      final flipIndex = 3 + 12; // first ciphertext byte
      tampered[flipIndex] = tampered[flipIndex] ^ 0xFF;
      await File(encPath).writeAsBytes(tampered);

      expect(
        () => EncryptionService.decryptFile(encPath),
        throwsA(anything),
        reason: 'GCM must detect ciphertext tampering',
      );
    });

    test('throws on empty encrypted file', () async {
      final dir = Directory.systemTemp.createTempSync('docvault_test_');
      final emptyEnc = File('${dir.path}/empty.enc');
      await emptyEnc.writeAsBytes([]);

      expect(
        () => EncryptionService.decryptFile(emptyEnc.path),
        throwsA(anything),
      );
    });
  });
}
