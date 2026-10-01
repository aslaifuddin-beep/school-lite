import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// مخزن آمن لتوكنات Moodle (wstoken) — كل حساب بخانة مستقلة.
///
/// يعتمد على Keystore/Keychain عبر flutter_secure_storage، ولا يُكتب
/// التوكن أبداً في SharedPreferences أو قاعدة البيانات المحلية.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _prefix = 'wstoken_';

  Future<void> write(String accountId, String token) =>
      _storage.write(key: '$_prefix$accountId', value: token);

  Future<String?> read(String accountId) =>
      _storage.read(key: '$_prefix$accountId');

  Future<void> delete(String accountId) =>
      _storage.delete(key: '$_prefix$accountId');

  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys.where((k) => k.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
  }
}
