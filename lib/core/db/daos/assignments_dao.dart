import 'package:drift/drift.dart';

import '../../network/content_source.dart';
import '../../network/dto.dart';
import '../app_database.dart';
import '../row_ids.dart';

/// DAO الواجبات — حالة التسليم محلية أولاً: أي إرسال في طابور المزامنة
/// (pendingSync) لا تلمسه مزامنة الخادم القادمة حتى يُرفع.
class AssignmentsDao {
  AssignmentsDao(this.db);

  final AppDatabase db;

  // --------------------------------------------------------------- القراءة
  /// واجبات الحساب: الأقرب موعداً أولاً، والبلا موعد في النهاية.
  Stream<List<Assignment>> watchAll(String accountId) {
    final query = db.select(db.assignments)
      ..where((t) => t.accountId.equals(accountId));
    return query.watch().map((rows) {
      final sorted = [...rows]..sort(_byDueDate);
      return sorted;
    });
  }

  static int _byDueDate(Assignment a, Assignment b) {
    final da = a.dueAt;
    final dbb = b.dueAt;
    if (da == null && dbb == null) return a.name.compareTo(b.name);
    if (da == null) return 1; // بلا موعد → آخر القائمة
    if (dbb == null) return -1;
    final cmp = da.compareTo(dbb);
    return cmp != 0 ? cmp : a.name.compareTo(b.name);
  }

  Future<Assignment?> byMoodleId(String accountId, int moodleId) {
    final query = db.select(db.assignments)
      ..where((t) => t.accountId.equals(accountId) & t.moodleId.equals(moodleId));
    return query.getSingleOrNull();
  }

  Future<Assignment?> byId(String id) {
    final query = db.select(db.assignments)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  // --------------------------------------------------------------- الكتابة
  /// استبدال واجبات مقرر واحد من الخادم مع الحفاظ على الحالة المحلية
  /// للواجبات المعلّقة في الطابور.
  Future<void> replaceCourseAssignments({
    required String accountId,
    required int courseMoodleId,
    required List<AssignmentDto> dtos,
  }) {
    final courseId = courseIdRow(accountId, courseMoodleId);
    return db.transaction(() async {
      // الواجبات الموجودة محلياً في هذا المقرر.
      final existingQuery = db.select(db.assignments)
        ..where((t) => t.accountId.equals(accountId) & t.courseId.equals(courseId));
      final existing = await existingQuery.get();
      final existingByMoodleId = {for (final a in existing) a.moodleId: a};

      final incomingIds = dtos.map((d) => d.id).toSet();

      // حذف ما لم يعد موجوداً على الخادم (وغير معلّق محلياً).
      for (final old in existing) {
        if (!incomingIds.contains(old.moodleId) && !old.pendingSync) {
          await (db.delete(db.assignments)..where((t) => t.id.equals(old.id))).go();
        }
      }

      final now = DateTime.now();
      for (final dto in dtos) {
        final local = existingByMoodleId[dto.id];
        final keepLocalState = local != null && local.pendingSync;

        // حالة محلية معلّقة تُحفظ كما هي، وإلا تُفضَّل قيمة الخادم
        // مع المحافظة على القديم إذا لم يُرسل الخادم هذا الحقل.
        final status = keepLocalState
            ? local.status
            : (dto.status != null
                ? _mapStatus(dto.status)
                : local?.status ?? 'not_submitted');

        await db.into(db.assignments).insert(
              AssignmentsCompanion.insert(
                id: rowId(accountId, dto.id),
                accountId: accountId,
                courseId: courseId,
                moodleId: dto.id,
                name: dto.name,
                intro: Value(dto.intro),
                dueAt: Value(dto.dueAt),
                submissionsFrom: Value(dto.submissionsFrom),
                allowLateSubmit: Value(dto.allowLateSubmit),
                status: Value(status),
                pendingSync: Value(keepLocalState),
                onlineText: Value(keepLocalState
                    ? local.onlineText
                    : dto.onlineText ?? local?.onlineText),
                gradeText: Value(keepLocalState
                    ? local.gradeText
                    : dto.gradeText ?? local?.gradeText),
                submittedAt: Value(keepLocalState
                    ? local.submittedAt
                    : dto.submittedAt ?? local?.submittedAt),
                updatedAt: now,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// دمج حالة التسليم (من get_submission_status) دون المساس بالطابور.
  Future<void> applyStatus({
    required String accountId,
    required int assignmentMoodleId,
    required SubmissionStatusDto status,
  }) async {
    final row = await byMoodleId(accountId, assignmentMoodleId);
    if (row == null || row.pendingSync) return;

    await (db.update(db.assignments)..where((t) => t.id.equals(row.id))).write(
      AssignmentsCompanion(
        status: Value(_mapStatus(status.status, fallback: row.status)),
        gradeText: Value(status.gradeText ?? row.gradeText),
        onlineText: Value(status.onlineText ?? row.onlineText),
        submittedAt: Value(status.submittedAt ?? row.submittedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// تعليم واجب كـ"في الطابور" عند حفظ إجابته محلياً.
  Future<void> setPending({
    required String accountId,
    required int assignmentMoodleId,
    required bool pending,
    String? onlineText,
  }) async {
    final row = await byMoodleId(accountId, assignmentMoodleId);
    if (row == null) return;

    await (db.update(db.assignments)..where((t) => t.id.equals(row.id))).write(
      AssignmentsCompanion(
        pendingSync: Value(pending),
        status: Value(pending ? 'queued' : row.status),
        onlineText: onlineText != null ? Value(onlineText) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// تحديث الحالة بعد نجاح/فشل رفع الطابور.
  Future<void> setStatusById({
    required String accountId,
    required int assignmentMoodleId,
    required String status,
    bool clearPending = false,
    DateTime? submittedAt,
  }) async {
    final row = await byMoodleId(accountId, assignmentMoodleId);
    if (row == null) return;

    await (db.update(db.assignments)..where((t) => t.id.equals(row.id))).write(
      AssignmentsCompanion(
        status: Value(status),
        pendingSync: clearPending ? const Value(false) : const Value.absent(),
        submittedAt: submittedAt != null ? Value(submittedAt) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// تحويل حالة الخادم (بصيغته) إلى حالتنا المحلية.
  static String _mapStatus(String? server, {String fallback = 'not_submitted'}) {
    switch (server) {
      case 'submitted':
      case 'draft':
        return 'submitted';
      case 'graded':
        return 'graded';
      case 'notsubmitted':
      case 'noattempt':
        return 'not_submitted';
      case null:
        return fallback;
      default:
        return server;
    }
  }

  /// تنظيف واجبات حساب محذوف.
  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.assignments)..where((t) => t.accountId.equals(accountId))).go();
  }
}
