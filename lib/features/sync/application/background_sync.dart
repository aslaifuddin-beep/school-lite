import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/content_source.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/moodle_content_source.dart';
import '../../../core/security/secure_token_store.dart';
import '../../../core/utils/url_utils.dart';
import '../../../features/accounts/data/accounts_repository.dart';
import '../../../features/accounts/domain/account.dart';
import 'sync_engine.dart';

/// معرّف مهمة المزامنة الخلفية (دورية كل ~30 دقيقة).
const kBackgroundSyncTaskName = 'school_lite_sync_v1';

/// تهيئة المهمة الخلفية — كل ما فيها محمي try/catch لأن المهمة الخلفية
/// اختيارية: فشلها لا يمسّ التطبيق أبداً (المزامنة الأمامية تكفي).
Future<void> initBackgroundSync() async {
  try {
    await Workmanager().initialize(_dispatchCallback);
    await Workmanager().registerPeriodicTask(
      kBackgroundSyncTaskName,
      kBackgroundSyncTaskName,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {
    // جهاز بلا دعم المهام الخلفية — نكمل عادياً.
    return;
  }
}

/// نقطة دخول workmanager (يُستدعى في isolate منفصل بلا Riverpod).
@pragma('vm:entry-point')
void _dispatchCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kBackgroundSyncTaskName) return false;
    try {
      await runBackgroundSync();
      return true;
    } catch (_) {
      // أي فشل غير متوقع → نعيد false ونجرّب في الدورة القادمة.
      return false;
    }
  });
}

/// مزامنة خلفية مستقلة: ترفع الطابور ثم تجلب المحتوى لكل حساب حقيقي.
///
/// تستخدم نفس ملف قاعدة البيانات (SQLite يتعامل مع التزامن بنفسه) ونفس
/// مخزن التوكنات الآمن، وتُحدّث آخر مزامنة في SharedPreferences مباشرة.
Future<void> runBackgroundSync() async {
  final prefs = await SharedPreferences.getInstance();
  final repo = PrefsAccountsRepository(prefs);
  final accounts = repo.loadAll();
  if (accounts.isEmpty) return;

  final db = AppDatabase();
  final client = DioClient();
  try {
    for (final account in accounts) {
      // الحسابات التجريبية لا تحتاج مزامنة — بياناتها محلية أصلاً.
      if (account.isDemo) continue;
      try {
        await _syncOneAccount(
          account: account,
          db: db,
          client: client,
          repo: repo,
          accounts: accounts,
        );
      } catch (_) {
        // حساب واحد يفشل → نكمل بقية الحسابات.
        continue;
      }
    }
  } finally {
    await client.close();
    await db.close();
  }
}

Future<void> _syncOneAccount({
  required Account account,
  required AppDatabase db,
  required DioClient client,
  required AccountsRepository repo,
  required List<Account> accounts,
}) async {
  final token = await SecureTokenStore().read(account.id);
  if (token == null || token.isEmpty) return;

  final session = MoodleSession(
    baseUrl: UrlUtils.normalizeServerUrl(account.serverUrl),
    token: token,
    userId: account.moodleUserId,
  );
  final engine = SyncEngine(db: db, source: MoodleContentSource(client));

  // رفع المعلّق ثم جلب الجديد (نفس ترتيب المزامنة الأمامية).
  await engine.processQueue(account, session);
  final result = await engine.syncAccount(account, session);
  if (!result.ok) return;

  // تحديث وقت آخر مزامنة مباشرة في مخزن الحسابات.
  final updated = [
    for (final a in accounts)
      if (a.id == account.id)
        a.copyWith(lastSyncedAt: DateTime.now())
      else
        a,
  ];
  await repo.saveAll(updated);
}
