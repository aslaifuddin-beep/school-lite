import '../../../core/db/app_database.dart';
import '../../../core/db/daos/assignments_dao.dart';
import '../../../core/db/daos/content_dao.dart';
import '../../../core/db/daos/extras_daos.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/network/content_source.dart';
import '../../../core/network/dto.dart';
import '../../../features/accounts/domain/account.dart';

/// نتيجة مزامنة واحدة — تُعرض في واجهة «آخر مزامنة».
class SyncResult {
  const SyncResult({
    required this.ok,
    this.offline = false,
    this.error,
    this.coursesCount = 0,
    this.assignmentsCount = 0,
    this.statusesCount = 0,
    this.eventsCount = 0,
    this.notificationsCount = 0,
  });

  final bool ok;

  /// فشل بسبب انقطاع الشبكة (لا رسالة خطأ للمستخدم، إعادة محاولة لاحقاً).
  final bool offline;

  final String? error;

  final int coursesCount;
  final int assignmentsCount;
  final int statusesCount;
  final int eventsCount;
  final int notificationsCount;
}

/// محرك المزامنة الأمامي (Foreground Engine) — يعمل بلا Riverpod ليُعاد
/// استخدامه في المهمة الخلفية (workmanager).
///
/// الترتيب المقصود:
/// 1) جلب المقررات (فشلها = فشل المزامنة كاملة).
/// 2) أقسام/وحدات كل مقرر (أفضل جهد — يُكمل ما تبقّى).
/// 3) واجبات المقررات مع الحفاظ على الحالة المحلية المعلّقة في الطابور.
/// 4) حالة التسليم لكل واجب (أفضل جهد، مقنّن).
/// 5) التقويم والإشعارات (أفضل جهد).
class SyncEngine {
  SyncEngine({required this.db, required this.source})
      : _content = ContentDao(db),
        _assignments = AssignmentsDao(db),
        _queue = SyncQueueDao(db),
        _calendar = CalendarDao(db),
        _notifications = NotificationsDao(db);

  final AppDatabase db;
  final ContentSource source;

  final ContentDao _content;
  final AssignmentsDao _assignments;
  final SyncQueueDao _queue;
  final CalendarDao _calendar;
  final NotificationsDao _notifications;

  /// حد أقصى لجلب حالات التسليم في دفعة واحدة (حماية من الطلبات الطويلة).
  static const maxStatusChecks = 40;

  Future<SyncResult> syncAccount(
    Account account,
    MoodleSession session,
  ) async {
    // 1) المقررات — خطوة مصيرية.
    final List<CourseDto> courses;
    try {
      courses = await source.fetchCourses(session);
    } on MoodleSourceException catch (e) {
      return SyncResult(ok: false, offline: e.isNetwork, error: e.message);
    } catch (e) {
      return SyncResult(ok: false, error: e.toString());
    }
    await _content.upsertCourses(account.id, courses);

    // 2) أقسام كل مقرر — أفضل جهد.
    for (final course in courses) {
      try {
        final bundles = await source.fetchCourseContents(session, course.id);
        await _content.replaceCourse(
          accountId: account.id,
          course: course,
          bundles: bundles,
        );
      } on MoodleSourceException catch (e) {
        if (e.isNetwork) {
          return SyncResult(
            ok: false,
            offline: true,
            error: e.message,
            coursesCount: courses.length,
          );
        }
        // خطأ صلاحيات/خادم في مقرر واحد → نكمل البقية.
      }
    }

    // 3) الواجبات لكل المقررات دفعة واحدة.
    var assignmentsCount = 0;
    var fetchedAssignments = const <AssignmentDto>[];
    final courseMoodleIds = courses.map((c) => c.id).toList();
    try {
      fetchedAssignments =
          await source.fetchAssignments(session, courseMoodleIds);
      final byCourse = <int, List<AssignmentDto>>{};
      for (final a in fetchedAssignments) {
        byCourse.putIfAbsent(a.courseMoodleId, () => []).add(a);
      }
      for (final entry in byCourse.entries) {
        await _assignments.replaceCourseAssignments(
          accountId: account.id,
          courseMoodleId: entry.key,
          dtos: entry.value,
        );
        assignmentsCount += entry.value.length;
      }
    } on MoodleSourceException catch (e) {
      if (e.isNetwork) {
        return SyncResult(
          ok: false,
          offline: true,
          error: e.message,
          coursesCount: courses.length,
        );
      }
    }

    // 4) حالة التسليم لكل واجب (أفضل جهد + قنّة).
    var statusesCount = 0;
    final uniqueIds = fetchedAssignments.map((a) => a.id).toSet().toList();
    for (final id in uniqueIds.take(maxStatusChecks)) {
      try {
        final status = await source.fetchSubmissionStatus(session, id);
        if (status != null) {
          await _assignments.applyStatus(
            accountId: account.id,
            assignmentMoodleId: id,
            status: status,
          );
          statusesCount++;
        }
      } catch (_) {
        // تجاهل: قد يرفض الخادم هذا الـ wsfunction لبعض الأدوار.
        break;
      }
    }

    // 5) التقويم والإشعارات — أفضل جهد.
    var eventsCount = 0;
    try {
      final events = await source.fetchUpcomingEvents(session);
      await _calendar.replaceAll(accountId: account.id, events: events);
      eventsCount = events.length;
    } catch (_) {
      // فشل التقويم لا يُفشل المزامنة — البيانات الأساسية محفوظة أصلاً.
      eventsCount = 0;
    }

    var notificationsCount = 0;
    try {
      final incoming = await source.fetchNotifications(session);
      await _notifications.merge(accountId: account.id, notifications: incoming);
      notificationsCount = incoming.length;
    } catch (_) {
      // الإشعارات اختيارية — نتجاهل الفشل.
      notificationsCount = 0;
    }

    return SyncResult(
      ok: true,
      coursesCount: courses.length,
      assignmentsCount: assignmentsCount,
      statusesCount: statusesCount,
      eventsCount: eventsCount,
      notificationsCount: notificationsCount,
    );
  }

  /// طابور التسليمات المعلّقة (يُستدعى قبل المزامنة العادية).
  Future<QueueProcessResult> processQueue(
    Account account,
    MoodleSession session,
  ) {
    return QueueProcessor(db: db, source: source, queue: _queue)
        .process(account: account, session: session);
  }
}

/// ملخص معالجة الطابور في دفعة واحدة.
class QueueProcessResult {
  const QueueProcessResult({
    this.sent = 0,
    this.failed = 0,
    this.offline = false,
  });

  final int sent;
  final int failed;

  /// انقطعت الشبكة في منتصف الدفعة — يتوقف الباقى لموعد لاحق.
  final bool offline;
}

/// معالج طابور التسليمات: يرفع المحفوظ محلياً بالترتيب مع backoff أسّي.
class QueueProcessor {
  QueueProcessor({
    required this.db,
    required this.source,
    required this.queue,
  }) : _assignments = AssignmentsDao(db);

  final AppDatabase db;
  final ContentSource source;
  final SyncQueueDao queue;
  final AssignmentsDao _assignments;

  Future<QueueProcessResult> process({
    required Account account,
    required MoodleSession session,
    DateTime? now,
  }) async {
    final due = await queue.dueEntries(accountId: account.id, now: now);
    var sent = 0;
    var failed = 0;

    for (final entry in due) {
      await queue.markSending(entry.id);
      try {
        final payload = queue.decodePayload(entry.payload);
        final text = payload.text;
        if (payload.filePaths.isNotEmpty) {
          await source.submitFiles(
            session,
            payload.assignmentMoodleId,
            payload.filePaths,
            text: text,
          );
        } else {
          await source.submitText(
            session,
            payload.assignmentMoodleId,
            text ?? '',
          );
        }

        // نجاح → حذف المدخل وتحديث حالة الواجب محلياً.
        await queue.markSent(entry.id);
        await _assignments.setStatusById(
          accountId: account.id,
          assignmentMoodleId: payload.assignmentMoodleId,
          status: 'submitted',
          clearPending: true,
          submittedAt: DateTime.now(),
        );
        sent++;
      } on MoodleSourceException catch (e) {
        await queue.markFailed(
          id: entry.id,
          error: e.message,
          isNetwork: e.isNetwork,
          retryCount: entry.retryCount,
        );
        failed++;
        if (e.isNetwork) {
          // بلا شبكة: لا معنى لاستمرار الرفع — ننتظر عودة الاتصال.
          return QueueProcessResult(sent: sent, failed: failed, offline: true);
        }
      } catch (e) {
        await queue.markFailed(
          id: entry.id,
          error: e.toString(),
          isNetwork: false,
          retryCount: entry.retryCount,
        );
        failed++;
      }
    }
    return QueueProcessResult(sent: sent, failed: failed);
  }
}
