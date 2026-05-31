import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static const _keyAlias = 'docvault_aes_key';
  static const _ivAlias = 'docvault_aes_iv';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static late enc.Key _key;
  static late enc.IV _iv;

  static Future<void> init() async {
    String? keyB64 = await _storage.read(key: _keyAlias);
    String? ivB64 = await _storage.read(key: _ivAlias);

    if (keyB64 == null || ivB64 == null) {
      final k = enc.Key.fromSecureRandom(32);
      final v = enc.IV.fromSecureRandom(16);
      await _storage.write(key: _keyAlias, value: k.base64);
      await _storage.write(key: _ivAlias, value: v.base64);
      keyB64 = k.base64;
      ivB64 = v.base64;
    }

    _key = enc.Key.fromBase64(keyB64);
    _iv = enc.IV.fromBase64(ivB64);
  }

  static Future<String> encryptFile(File source) async {
    final bytes = await source.readAsBytes();
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: _iv);

    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (!await encDir.exists()) await encDir.create(recursive: true);

    final file = File('${encDir.path}/${const Uuid().v4()}.enc');
    await file.writeAsBytes(encrypted.bytes);
    return file.path;
  }

  static Future<Uint8List> decryptFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final decrypted =
        encrypter.decryptBytes(enc.Encrypted(bytes), iv: _iv);
    return Uint8List.fromList(decrypted);
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
    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory('${dir.path}/enc');
    if (await encDir.exists()) {
      await encDir.delete(recursive: true);
    }
  }
}
