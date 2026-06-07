import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static const _keyAlias = 'docvault_aes_key';
  static const _legacyIvAlias = 'docvault_aes_iv'; // Keep for legacy CBC
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
    ),
  );

  static late enc.Key _key;
  static enc.IV? _legacyIv;

  @visibleForTesting
  static void initForTesting(enc.Key key, {enc.IV? legacyIv}) {
    _key = key;
    _legacyIv = legacyIv;
  }

  @visibleForTesting
  static Directory? encDirOverride;

  static Future<void> init() async {
    String? keyB64;
    String? legacyIvB64;
    try {
      keyB64 = await _storage.read(key: _keyAlias);
      legacyIvB64 = await _storage.read(key: _legacyIvAlias);
    } catch (e) {
      throw Exception('Secure Storage Error: Device Keystore invalidated. Error: $e');
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

    await clearTempFiles();
  }

  static Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (var f in files) {
          if (f is File) {
            try { await f.delete(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  static Future<String> encryptFile(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (!await encDir.exists()) await encDir.create(recursive: true);

    // Default to AES-256-GCM (Version 1) for all new files.
    // Always use compute() to keep UI perfectly smooth.
    return await compute(_backgroundEncrypt, _EncryptArgs(
      sourcePath: source.path,
      keyBase64: _key.base64,
      outputDirPath: encDirOverride?.path ?? encDir.path,
    ));
  }

  static Future<Uint8List> decryptFile(String path) async {
    return await compute(_backgroundDecrypt, _DecryptArgs(
      path: path,
      keyBase64: _key.base64,
      legacyIvBase64: _legacyIv?.base64,
    ));
  }

  static Future<Uint8List> _decryptGcm(Uint8List data, {required int headerLength, required enc.Key key}) async {
    if (data.length < headerLength + 12) throw Exception('Invalid GCM file');
    final iv = enc.IV(data.sublist(headerLength, headerLength + 12));
    final encBytes = data.sublist(headerLength + 12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(encBytes), iv: iv));
  }

  static Uint8List _decryptLegacyCbc(Uint8List data, enc.Key key, enc.IV? legacyIv) {
    if (legacyIv == null) throw Exception('Legacy IV not found');
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(data), iv: legacyIv));
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  static Future<File> decryptToTemp(String path, String ext) async {
    final tempDir = await getTemporaryDirectory();
    
    // Always use compute() for AES-GCM to ensure the UI remains smooth.
    final tempPath = await compute(_backgroundDecryptToTemp, _DecryptToTempArgs(
      path: path,
      keyBase64: _key.base64,
      legacyIvBase64: _legacyIv?.base64,
      tempDirPath: tempDir.path,
      ext: ext,
    ));
    return File(tempPath);
  }

  static Future<void> deleteEncryptedFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> clearAllFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (await encDir.exists()) await encDir.delete(recursive: true);
    await clearTempFiles();
  }
}

class _DecryptArgs {
  final String path;
  final String keyBase64;
  final String? legacyIvBase64;
  _DecryptArgs({required this.path, required this.keyBase64, this.legacyIvBase64});
}

Future<Uint8List> _backgroundDecrypt(_DecryptArgs args) async {
  final data = await File(args.path).readAsBytes();
  if (data.isEmpty) throw Exception('Empty file');
  final key = enc.Key.fromBase64(args.keyBase64);
  
  // AES-GCM (Version 1)
  if (data.length >= 3 && data[0] == 0x44 && data[1] == 0x56 && data[2] == 0x01) {
    return await EncryptionService._decryptGcm(data, headerLength: 3, key: key);
  }

  if (data[0] == 0x01) {
    try {
      return await EncryptionService._decryptGcm(data, headerLength: 1, key: key);
    } catch (_) {
      if (args.legacyIvBase64 == null) rethrow;
    }
  }

  final legacyIv = args.legacyIvBase64 != null ? enc.IV.fromBase64(args.legacyIvBase64!) : null;
  return EncryptionService._decryptLegacyCbc(data, key, legacyIv);
}

class _EncryptArgs {
  final String sourcePath;
  final String keyBase64;
  final String outputDirPath;
  _EncryptArgs({required this.sourcePath, required this.keyBase64, required this.outputDirPath});
}

Future<String> _backgroundEncrypt(_EncryptArgs args) async {
  final bytes = await File(args.sourcePath).readAsBytes();
  final key = enc.Key.fromBase64(args.keyBase64);
  
  // Use military-grade AES-256-GCM
  final iv = enc.IV.fromSecureRandom(12);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  final encrypted = encrypter.encryptBytes(bytes, iv: iv);

  // Magic: ["DV" + version 1] + [IV 12] + [Encrypted Data]
  final magic = [0x44, 0x56, 0x01];
  final result = Uint8List(magic.length + iv.bytes.length + encrypted.bytes.length);
  result.setAll(0, magic);
  result.setAll(magic.length, iv.bytes);
  result.setAll(magic.length + iv.bytes.length, encrypted.bytes);

  final outPath = '${args.outputDirPath}/${const Uuid().v4()}.enc';
  await File(outPath).writeAsBytes(result);
  return outPath;
}

class _DecryptToTempArgs {
  final String path;
  final String keyBase64;
  final String? legacyIvBase64;
  final String tempDirPath;
  final String ext;
  _DecryptToTempArgs({required this.path, required this.keyBase64, this.legacyIvBase64, required this.tempDirPath, required this.ext});
}

Future<String> _backgroundDecryptToTemp(_DecryptToTempArgs args) async {
  final data = await File(args.path).readAsBytes();
  if (data.isEmpty) throw Exception('Empty file');
  final key = enc.Key.fromBase64(args.keyBase64);

  Uint8List decrypted;
  // AES-GCM (Version 1)
  if (data.length >= 3 && data[0] == 0x44 && data[1] == 0x56 && data[2] == 0x01) {
    decrypted = await EncryptionService._decryptGcm(data, headerLength: 3, key: key);
  } else if (data[0] == 0x01) {
    try {
      decrypted = await EncryptionService._decryptGcm(data, headerLength: 1, key: key);
    } catch (_) {
      final legacyIv = args.legacyIvBase64 != null ? enc.IV.fromBase64(args.legacyIvBase64!) : null;
      decrypted = EncryptionService._decryptLegacyCbc(data, key, legacyIv);
    }
  } else {
    final legacyIv = args.legacyIvBase64 != null ? enc.IV.fromBase64(args.legacyIvBase64!) : null;
    decrypted = EncryptionService._decryptLegacyCbc(data, key, legacyIv);
  }

  final outPath = '${args.tempDirPath}/${const Uuid().v4()}.${args.ext}';
  await File(outPath).writeAsBytes(decrypted);
  return outPath;
}
