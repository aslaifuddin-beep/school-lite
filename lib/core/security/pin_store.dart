import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين رمز PIN محلي بشكل آمن: يُحفظ «مُجزَّأ» (SHA-256 + ملح عشوائي)
/// ولا يُحفظ الرمز نفسه أبداً.
class PinStore {
  PinStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kHash = 'pin_hash_v1';
  static const _kSalt = 'pin_salt_v1';

  bool get isSet => _prefs.containsKey(_kHash);

  Future<void> set(String pin) async {
    final salt = _generateSalt();
    await _prefs.setString(_kSalt, salt);
    await _prefs.setString(_kHash, _hash(pin, salt));
  }

  bool verify(String pin) {
    final salt = _prefs.getString(_kSalt);
    final stored = _prefs.getString(_kHash);
    if (salt == null || stored == null) return false;
    return _hash(pin, salt) == stored;
  }

  Future<void> clear() async {
    await _prefs.remove(_kHash);
    await _prefs.remove(_kSalt);
  }

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
