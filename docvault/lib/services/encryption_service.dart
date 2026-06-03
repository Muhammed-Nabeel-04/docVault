import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static const _keyAlias = 'docvault_aes_key';
  static const _legacyIvAlias = 'docvault_aes_iv'; // Keep for legacy CBC
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static late enc.Key _key;
  static enc.IV? _legacyIv;

  static Future<void> init() async {
    String? keyB64 = await _storage.read(key: _keyAlias);
    String? legacyIvB64 = await _storage.read(key: _legacyIvAlias);

    if (keyB64 == null) {
      final k = enc.Key.fromSecureRandom(32);
      await _storage.write(key: _keyAlias, value: k.base64);
      keyB64 = k.base64;
    }

    _key = enc.Key.fromBase64(keyB64);
    if (legacyIvB64 != null) {
      _legacyIv = enc.IV.fromBase64(legacyIvB64);
    }
    
    // Cleanup any stale temp files from previous sessions/crashes
    await clearTempFiles();
  }

  static Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (var f in files) {
          if (f is File) {
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  static Future<String> encryptFile(File source) async {
    final bytes = await source.readAsBytes();
    final iv = enc.IV.fromSecureRandom(12); // GCM standard nonce length
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (!await encDir.exists()) await encDir.create(recursive: true);

    final file = File('${encDir.path}/${const Uuid().v4()}.enc');
    
    // Format: [Version Byte (1)] + [IV (12)] + [Data (ciphertext + tag)]
    final combined = Uint8List(1 + iv.bytes.length + encrypted.bytes.length);
    combined[0] = 0x01; // Version 1: AES-GCM
    combined.setAll(1, iv.bytes);
    combined.setAll(1 + iv.bytes.length, encrypted.bytes);
    
    await file.writeAsBytes(combined);
    return file.path;
  }

  static Future<Uint8List> decryptFile(String path) async {
    final data = await File(path).readAsBytes();
    if (data.isEmpty) throw Exception('Empty file');

    final version = data[0];

    if (version == 0x01) {
      // Version 1: AES-GCM
      if (data.length < 13) throw Exception('Invalid GCM file');
      final ivBytes = data.sublist(1, 13);
      final encBytes = data.sublist(13);
      
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
      return Uint8List.fromList(
          encrypter.decryptBytes(enc.Encrypted(encBytes), iv: iv));
    } else {
      // Legacy CBC or unknown - try CBC fallback
      if (_legacyIv == null) throw Exception('Legacy IV not found');
      
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      try {
        return Uint8List.fromList(
            encrypter.decryptBytes(enc.Encrypted(data), iv: _legacyIv!));
      } catch (e) {
        throw Exception('Decryption failed (legacy fallback also failed): $e');
      }
    }
  }

  static Future<File> decryptToTemp(String path, String ext) async {
    final bytes = await decryptFile(path);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${const Uuid().v4()}.$ext');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> deleteEncryptedFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> clearAllFiles() async {
    // Clear encrypted files
    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (await encDir.exists()) {
      await encDir.delete(recursive: true);
    }
    
    // Clear temp decrypted files
    await clearTempFiles();
  }
}
