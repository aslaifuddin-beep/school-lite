import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/storage/prefs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../data/accounts_repository.dart';
import '../domain/account.dart';

/// مزوّد مخزن الحسابات (يُستبدل بـ Drift في الخطوة 2 بنفس الواجهة).
final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => PrefsAccountsRepository(ref.watch(sharedPrefsProvider)),
);

/// الحسابات المسجّلة على الجهاز (مرتبة، حد أقصى 10).
final accountsProvider =
    NotifierProvider<AccountsController, List<Account>>(AccountsController.new);

/// معرّف الحساب النشط — التبديل محلي بالكامل (أقل من ثانية).
final activeAccountIdProvider =
    NotifierProvider<ActiveAccountIdController, String?>(
  ActiveAccountIdController.new,
);

/// الحساب النشط جاهزاً للاستهلاك في الواجهات.
final activeAccountProvider = Provider<Account?>((ref) {
  final accounts = ref.watch(accountsProvider);
  final id = ref.watch(activeAccountIdProvider);
  if (accounts.isEmpty) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return accounts.first;
});

/// استثناء تجاوز حد الحسابات (10).
class AccountsLimitException implements Exception {
  const AccountsLimitException();
}

class AccountsController extends Notifier<List<Account>> {
  static const maxAccounts = 10;

  @override
  List<Account> build() => ref.read(accountsRepositoryProvider).loadAll();

  /// إضافة حساب جديد وتجعله النشط فوراً.
  Future<void> add({
    required String serverUrl,
    required String username,
    required String displayName,
    required String token,
    int? moodleUserId,
    String? avatarUrl,
    bool isDemo = false,
  }) async {
    if (state.length >= maxAccounts) throw const AccountsLimitException();

    final account = Account(
      id: newId('acc'),
      serverUrl: serverUrl,
      username: username,
      displayName: displayName,
      moodleUserId: moodleUserId,
      avatarUrl: avatarUrl,
      isDemo: isDemo,
      colorIndex: _nextColorIndex(),
      sortOrder: state.length,
      createdAt: DateTime.now(),
    );

    await ref.read(secureTokenStoreProvider).write(account.id, token);
    final updated = [...state, account];
    state = updated;
    await ref.read(accountsRepositoryProvider).saveAll(updated);
    await ref.read(activeAccountIdProvider.notifier).select(account.id);
  }

  /// حذف حساب وكل أثره المحلي (بما فيه التوكن الآمن وبيانات قاعدة البيانات).
  Future<void> remove(String id) async {
    final wasActive = ref.read(activeAccountIdProvider) == id;
    final updated = state.where((a) => a.id != id).toList();
    state = updated;
    await ref.read(accountsRepositoryProvider).saveAll(updated);
    await ref.read(secureTokenStoreProvider).delete(id);
    await purgeAccountData(ref.read(databaseProvider), id);

    if (wasActive) {
      await ref
          .read(activeAccountIdProvider.notifier)
          .select(updated.isEmpty ? null : updated.first.id);
    }
  }

  /// تحديث وقت آخر مزامنة ناجحة للحساب (تُستدعى من محرك المزامنة).
  Future<void> markSynced(String id) async {
    final now = DateTime.now();
    final updated = [
      for (final a in state)
        if (a.id == id)
          a.copyWith(lastSyncedAt: now)
        else
          a,
    ];
    state = updated;
    await ref.read(accountsRepositoryProvider).saveAll(updated);
  }

  /// اختيار أول لون غير مستخدم لتمييز الطالب بصرياً.
  int _nextColorIndex() {
    final used = state.map((a) => a.colorIndex).toSet();
    for (var i = 0; i < AppColors.accountColors.length; i++) {
      if (!used.contains(i)) return i;
    }
    return state.length % AppColors.accountColors.length;
  }
}

class ActiveAccountIdController extends Notifier<String?> {
  static const _key = 'active_account_id_v1';

  @override
  String? build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final accounts = ref.watch(accountsProvider);
    if (accounts.isEmpty) return null;

    final saved = prefs.getString(_key);
    if (saved != null && accounts.any((a) => a.id == saved)) return saved;
    return accounts.first.id;
  }

  Future<void> select(String? id) async {
    state = id;
    final prefs = ref.read(sharedPrefsProvider);
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
  }
}
