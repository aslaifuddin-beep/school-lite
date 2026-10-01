import 'dart:convert';

import 'package:drift/drift.dart';

import '../../network/dto.dart';
import '../../utils/id_generator.dart';
import '../app_database.dart';

/// DAO طابور المزامنة — كل تسليم يُحفظ أولاً ثم يُرفع لاحقاً.
///
/// قواعد الطابور:
/// • enqueue → status=pending وnextAttemptAt=الآن.
/// • الالمعالج يعلّمه sending قبل الرفع، ثم يحذفه عند النجاح.
/// • عند الفشل: retryCount++ و backoff أسّي (60s × 2^n كحد أقصى ساعة)
///   ما لم يكن الخطأ شبكة — عندها يبقى المدخل pending بانتظار عودة الإنترنت.
class SyncQueueDao {
  SyncQueueDao(this.db);

  final AppDatabase db;

  /// إضافة تسليم إلى الطابور ويعيد المعرّف.
  Future<String> enqueue({
    required String accountId,
    required SubmissionPayload payload,
  }) async {
    final id = newId('q');
    final now = DateTime.now();
    await db.into(db.syncQueueEntries).insert(
          SyncQueueEntriesCompanion.insert(
            id: id,
            accountId: accountId,
            type: 'submit_assignment',
            payload: jsonEncode(payload.toJson()),
            status: const Value('pending'),
            createdAt: now,
            nextAttemptAt: now,
          ),
        );
    return id;
  }

  /// فك حمولة طابور (JSON من jsonEncode أعلاه).
  SubmissionPayload decodePayload(String raw) =>
      SubmissionPayload.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());

  /// المدخلات الجاهزة للرفع الآن (pending/failed ولها وقت المحاولة).
  Future<List<SyncQueueEntry>> dueEntries({
    required String accountId,
    DateTime? now,
    int limit = 10,
  }) {
    final at = now ?? DateTime.now();
    final query = db.select(db.syncQueueEntries)
      ..where((t) =>
          t.accountId.equals(accountId) &
          t.status.isNotIn(const ['sending']) &
          t.nextAttemptAt.isSmallerOrEqualValue(at))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(limit);
    return query.get();
  }

  /// عدد المدخلات غير المرفوعة (pending أو failed) لحساب — لشارة الواجهة.
  Stream<int> pendingCount(String accountId) {
    final query = db.select(db.syncQueueEntries)
      ..where((t) =>
          t.accountId.equals(accountId) &
          t.status.isNotIn(const ['sending']) &
          t.status.isNotIn(const ['done']));
    return query.watch().map((rows) => rows.length);
  }

  Future<void> markSending(String id) async {
    await (db.update(db.syncQueueEntries)..where((t) => t.id.equals(id))).write(
      const SyncQueueEntriesCompanion(status: Value('sending')),
    );
  }

  /// نجاح الرفع → يُحذف المدخل (أرشفته غير مطلوبة).
  Future<void> markSent(String id) async {
    await (db.delete(db.syncQueueEntries)..where((t) => t.id.equals(id))).go();
  }

  /// فشل الرفع →
  /// • خطأ شبكة: يبقى pending وجاهزاً فوراً (يُعاد عند عودة الاتصال).
  /// • خطأ خادم/صلاحيات: backoff أسّي لتجنّب إغراق الخادم (60s × 2^n).
  Future<void> markFailed({
    required String id,
    required String error,
    required bool isNetwork,
    int retryCount = 0,
  }) async {
    final next = retryCount + 1;
    var backoffSeconds = 0;
    if (!isNetwork) {
      final exponent = next > 5 ? 5 : next;
      backoffSeconds = 60 * (1 << exponent);
      if (backoffSeconds > 3600) backoffSeconds = 3600;
    }
    await (db.update(db.syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: Value(isNetwork ? 'pending' : 'failed'),
        retryCount: Value(next),
        lastError: Value(error),
        nextAttemptAt: Value(
          DateTime.now().add(Duration(seconds: backoffSeconds)),
        ),
      ),
    );
  }

  /// تنظيف طابور حساب محذوف.
  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.syncQueueEntries)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}
