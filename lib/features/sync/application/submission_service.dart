import '../../../core/db/app_database.dart';
import '../../../core/db/daos/assignments_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/network/dto.dart';

/// خدمة التسليم بأسلوب Offline-First:
///
/// 1) الإجابة تُحفظ فوراً في قاعدة البيانات (status=queued + pendingSync)
///    وتدخل الطابور في معاملة ذرّية واحدة — لا ضياع إطلاقاً.
/// 2) يحاول المعالج الرفع فوراً إن كان هناك إنترنت، وإلا يبقى في الطابور
///    حتى تعود الشبكة (مزامنة يدوية/تلقائية/خلفية).
class SubmissionService {
  SubmissionService(this.db)
      : _assignments = AssignmentsDao(db),
        _queue = SyncQueueDao(db);

  final AppDatabase db;
  final AssignmentsDao _assignments;
  final SyncQueueDao _queue;

  /// حفظ إجابة نصية محلياً وإدخالها في الطابور.
  Future<void> saveTextSubmission({
    required String accountId,
    required int assignmentMoodleId,
    required String text,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError('الإجابة فارغة');
    }
    await db.transaction(() async {
      await _assignments.setPending(
        accountId: accountId,
        assignmentMoodleId: assignmentMoodleId,
        pending: true,
        onlineText: text,
      );
      await _queue.enqueue(
        accountId: accountId,
        payload: SubmissionPayload(
          assignmentMoodleId: assignmentMoodleId,
          text: text,
        ),
      );
    });
  }

  /// حفظ ملفات (مع إجابة نصية اختيارية) في الطابور.
  Future<void> saveFileSubmission({
    required String accountId,
    required int assignmentMoodleId,
    required List<String> filePaths,
    String? text,
  }) async {
    if (filePaths.isEmpty && (text == null || text.trim().isEmpty)) {
      throw ArgumentError('لا يوجد ما يُسلَّم');
    }
    await db.transaction(() async {
      await _assignments.setPending(
        accountId: accountId,
        assignmentMoodleId: assignmentMoodleId,
        pending: true,
        onlineText: text,
      );
      await _queue.enqueue(
        accountId: accountId,
        payload: SubmissionPayload(
          assignmentMoodleId: assignmentMoodleId,
          text: text,
          filePaths: filePaths,
        ),
      );
    });
  }
}
