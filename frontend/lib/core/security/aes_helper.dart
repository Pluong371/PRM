import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';

/// AES encryption helper matching backend's AesUtil.java
/// Backend: AES/ECB/PKCS5Padding, key = SHA-1(secretKey) first 16 bytes
class AesHelper {
  static const String _defaultKey =
      'e4a4d0b3ea55b66aea6c799477aba6417e7ef3526533939c8b46cda38aff0d42';

  static encrypt_lib.Key _deriveKey(String secretKey) {
    // SHA-1 hash of the key string, then take first 16 bytes (AES-128)
    final keyBytes = utf8.encode(secretKey);
    final sha1Hash = sha1.convert(keyBytes);
    final first16 = Uint8List.fromList(sha1Hash.bytes.sublist(0, 16));
    return encrypt_lib.Key(first16);
  }

  /// Encrypt plaintext using AES/ECB/PKCS5Padding (Base64 output)
  static String encryptPassword(String plainText, {String? key}) {
    final aesKey = _deriveKey(key ?? _defaultKey);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(aesKey, mode: encrypt_lib.AESMode.ecb, padding: 'PKCS7'),
    );
    final encrypted = encrypter.encrypt(plainText);
    return encrypted.base64;
  }
}
