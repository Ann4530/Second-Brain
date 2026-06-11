import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for journal text at rest.
///
/// The key is generated once per install and kept in the platform keystore via
/// flutter_secure_storage. Ciphertext format (all base64, '.'-joined):
///   v1.<nonce>.<ciphertext>.<mac>
class CryptoService {
  CryptoService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'entry_aes_key_v1';
  final FlutterSecureStorage _storage;
  final AesGcm _aes = AesGcm.with256bits();
  SecretKey? _key;

  Future<SecretKey> _getKey() async {
    if (_key != null) return _key!;
    final stored = await _storage.read(key: _keyName);
    if (stored != null) {
      _key = SecretKey(base64Decode(stored));
      return _key!;
    }
    final key = await _aes.newSecretKey();
    final bytes = await key.extractBytes();
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    _key = key;
    return key;
  }

  Future<String> encrypt(String plaintext) async {
    final key = await _getKey();
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return 'v1.${base64Encode(box.nonce)}.'
        '${base64Encode(box.cipherText)}.${base64Encode(box.mac.bytes)}';
  }

  Future<String> decrypt(String payload) async {
    // Tolerate legacy/plaintext values (e.g. dev data before encryption).
    if (!payload.startsWith('v1.')) return payload;
    final parts = payload.split('.');
    if (parts.length != 4) return payload;
    final key = await _getKey();
    final box = SecretBox(
      base64Decode(parts[2]),
      nonce: base64Decode(parts[1]),
      mac: Mac(base64Decode(parts[3])),
    );
    final clear = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }
}
