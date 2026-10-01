import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account.dart';

/// واجهة مخزن الحسابات — تُستبدل لاحقاً بـ Drift/SQLite في خطوة المزامنة.
abstract class AccountsRepository {
  List<Account> loadAll();
  Future<void> saveAll(List<Account> accounts);
}

/// تنفيذ مؤقت مبني على SharedPreferences (سريع جداً عند الإقلاع).
///
/// ملاحظة: في «الخطوة 2» يستبدل هذا التنفيذ بقاعدة Drift المحلية
/// مع الاحتفاظ بنفس الواجهة — دون تغيير بقية التطبيق.
class PrefsAccountsRepository implements AccountsRepository {
  PrefsAccountsRepository(this._prefs);

  static const _key = 'accounts_v1';
  final SharedPreferences _prefs;

  @override
  List<Account> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final accounts = list
          .map((e) => Account.fromMap(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return accounts;
    } catch (_) {
      // بيانات تالفة → نبدأ بقائمة نظيفة بدل تعطيل التطبيق.
      return [];
    }
  }

  @override
  Future<void> saveAll(List<Account> accounts) async {
    final json = jsonEncode(accounts.map((a) => a.toMap()).toList());
    await _prefs.setString(_key, json);
  }
}
