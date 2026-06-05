import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static const _keyAlias = 'docvault_aes_key';
  static const _legacyIvAlias = 'docvault_aes_iv'; // Keep for legacy CBC
  static const _magicHeader = [0x44, 0x56, 0x01]; // "DV" + version 1
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
    ),
  );

  static late enc.Key _key;
  static enc.IV? _legacyIv;

  static Future<void> init() async {
    String? keyB64;
    String? legacyIvB64;
    try {
      keyB64 = await _storage.read(key: _keyAlias);
      legacyIvB64 = await _storage.read(key: _legacyIvAlias);
    } catch (e) {
      throw Exception('Secure Storage Error: Device Keystore invalidated (e.g. from lock screen changes). Data is safely encrypted but cannot be read without the original key. Error: $e');
    }

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

    // Format: ["DV" + version (3)] + [IV (12)] + [Data (ciphertext + tag)]
    final combined = Uint8List(
      _magicHeader.length + iv.bytes.length + encrypted.bytes.length,
    );
    combined.setAll(0, _magicHeader);
    combined.setAll(_magicHeader.length, iv.bytes);
    combined.setAll(_magicHeader.length + iv.bytes.length, encrypted.bytes);

    await file.writeAsBytes(combined);
    return file.path;
  }

  static Future<Uint8List> decryptFile(String path) async {
    return await compute(_backgroundDecrypt, _DecryptArgs(
      path: path,
      keyBase64: _key.base64,
      legacyIvBase64: _legacyIv?.base64,
    ));
  }

  static bool _hasMagicHeader(Uint8List data) {
    if (data.length < _magicHeader.length) return false;
    for (var i = 0; i < _magicHeader.length; i++) {
      if (data[i] != _magicHeader[i]) return false;
    }
    return true;
  }

  static Future<Uint8List> _decryptGcm(
    Uint8List data, {
    required int headerLength,
    required enc.Key key,
  }) async {
    if (data.length < headerLength + 12) throw Exception('Invalid GCM file');
    final ivBytes = data.sublist(headerLength, headerLength + 12);
    final encBytes = data.sublist(headerLength + 12);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(encBytes), iv: iv));
  }

  static Uint8List _decryptLegacyCbc(Uint8List data, enc.Key key, enc.IV? legacyIv) {
    if (legacyIv == null) throw Exception('Legacy IV not found');

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      return Uint8List.fromList(
          encrypter.decryptBytes(enc.Encrypted(data), iv: legacyIv));
    } catch (e) {
      throw Exception('Decryption failed (legacy fallback also failed): $e');
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

class _DecryptArgs {
  final String path;
  final String keyBase64;
  final String? legacyIvBase64;

  _DecryptArgs({
    required this.path,
    required this.keyBase64,
    this.legacyIvBase64,
  });
}

Future<Uint8List> _backgroundDecrypt(_DecryptArgs args) async {
  final data = await File(args.path).readAsBytes();
  if (data.isEmpty) throw Exception('Empty file');

  final key = enc.Key.fromBase64(args.keyBase64);
  final legacyIv = args.legacyIvBase64 != null 
      ? enc.IV.fromBase64(args.legacyIvBase64!) 
      : null;

  // magicHeader check logic (duplicated for isolate safety or use constant)
  bool hasMagic(Uint8List d) {
    const magic = [0x44, 0x56, 0x01];
    if (d.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (d[i] != magic[i]) return false;
    }
    return true;
  }

  if (hasMagic(data)) {
    return await EncryptionService._decryptGcm(data, headerLength: 3, key: key);
  }

  if (data[0] == 0x01) {
    try {
      return await EncryptionService._decryptGcm(data, headerLength: 1, key: key);
    } catch (_) {
      if (legacyIv == null) rethrow;
    }
  }

  return EncryptionService._decryptLegacyCbc(data, key, legacyIv);
}
