import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class KeyStore {
  Future<String?> read(String provider);
  Future<void> write(String provider, String key);
}

class SecureKeyStore implements KeyStore {
  const SecureKeyStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String provider) =>
      _storage.read(key: 'tixun.api.$provider');
  @override
  Future<void> write(String provider, String key) async {
    if (key.isEmpty) {
      await _storage.delete(key: 'tixun.api.$provider');
    } else {
      await _storage.write(key: 'tixun.api.$provider', value: key);
      if (await read(provider) != key) throw StateError('密钥保存校验失败');
    }
  }
}

class MemoryKeyStore implements KeyStore {
  final _keys = <String, String>{};
  @override
  Future<String?> read(String provider) async => _keys[provider];
  @override
  Future<void> write(String provider, String key) async {
    _keys[provider] = key;
  }
}
