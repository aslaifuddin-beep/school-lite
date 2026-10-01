import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/content_source.dart';
import '../../../core/network/demo_content_source.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/moodle_content_source.dart';
import '../../../core/security/secure_token_store.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/utils/url_utils.dart';
import '../../../features/accounts/application/accounts_providers.dart';
import '../../../features/accounts/domain/account.dart';
import 'submission_service.dart';

/// مصنع مصدر المحتوى: تجريبي للحسابات الموسومة، وشبكة لبقية الحسابات.
final contentSourceFactoryProvider =
    Provider<ContentSource Function(Account)>((ref) {
  final client = ref.watch(dioClientProvider);
  final real = MoodleContentSource(client);
  final demo = DemoContentSource();
  return (account) => account.isDemo ? demo : real;
});

/// بناء جلسة اتصال لحساب: التوكن من المخزن الآمن (أو قيمة تجريبية).
Future<MoodleSession> createSession({
  required SecureTokenStore tokenStore,
  required Account account,
}) async {
  final token =
      account.isDemo ? 'demo' : await tokenStore.read(account.id);
  if (token == null || token.isEmpty) {
    throw const MoodleSourceException('انتهى الجلسة — سجّل الدخول مجدداً');
  }
  return MoodleSession(
    baseUrl: UrlUtils.normalizeServerUrl(account.serverUrl),
    token: token,
    userId: account.moodleUserId,
  );
}

/// خدمة حفظ التسليمات محلياً (Offline-First).
final submissionServiceProvider = Provider<SubmissionService>(
  (ref) => SubmissionService(ref.watch(databaseProvider)),
);

/// عدد التسليمات المعلّقة في الطابور للحساب النشط — لشارة الواجهة.
final pendingSubmissionsProvider = StreamProvider<int>((ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return Stream<int>.value(0);
  return ref.watch(daosProvider).queue.pendingCount(accountId);
});

/// واجبات الحساب النشط مرتبة بمواعيدها (تتحدث تلقائياً عند أي تغيير DB).
final assignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return Stream<List<Assignment>>.value(const []);
  return ref.watch(daosProvider).assignments.watchAll(accountId);
});

/// مقررات الحساب النشط.
final coursesProvider = StreamProvider<List<Course>>((ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return Stream<List<Course>>.value(const []);
  return ref.watch(daosProvider).content.watchCourses(accountId);
});
