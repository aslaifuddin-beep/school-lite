import 'dto.dart';

/// جلسة اتصال بخادم Moodle لحساب طالب محدد (الرابط + التوكن).
class MoodleSession {
  const MoodleSession({
    required this.baseUrl,
    required this.token,
    this.userId,
  });

  final String baseUrl;
  final String token;
  final int? userId;
}

/// خطأ مصدر المحتوى — قد يكون شبكة أو خادم، ورسالته جاهزة للعرض.
class MoodleSourceException implements Exception {
  const MoodleSourceException(
    this.message, {
    this.isNetwork = false,
    this.errorCode,
  });

  final String message;
  final bool isNetwork;
  final String? errorCode;

  @override
  String toString() => message;
}

/// حالة تسليم واجب مأخوذة من mod_assign_get_submission_status.
class SubmissionStatusDto {
  const SubmissionStatusDto({
    this.status,
    this.onlineText,
    this.gradeText,
    this.submittedAt,
  });

  /// draft | submitted | graded … (حسب إصدار Moodle)
  final String? status;
  final String? onlineText;
  final String? gradeText;
  final DateTime? submittedAt;
}

/// عقد مصدر المحتوى: تنفيذه الحقيقي عبر الشبكة، وتنفيذه التجريبي محلياً.
///
/// المحرك لا يعرف الفرق — هذا ما يجعل الوضع التجريبي والمزامنة قابلين
/// للاختبار بلا شبكة إطلاقاً.
abstract class ContentSource {
  /// مقررات الطالب المسجّل فيها.
  Future<List<CourseDto>> fetchCourses(MoodleSession session);

  /// أقسام مقرر واحد مع عناصره (دروس/ملفات/روابط).
  Future<List<SectionBundleDto>> fetchCourseContents(
    MoodleSession session,
    int courseMoodleId,
  );

  /// واجبات مجموعة مقررات.
  Future<List<AssignmentDto>> fetchAssignments(
    MoodleSession session,
    List<int> courseMoodleIds,
  );

  /// حالة تسليم واجب واحد (أفضل جهد — قد يفشل بلا صلاحيات).
  Future<SubmissionStatusDto?> fetchSubmissionStatus(
    MoodleSession session,
    int assignmentMoodleId,
  );

  /// مواعيد الأحداث/التسليم القادمة من التقويم.
  Future<List<CalendarEventDto>> fetchUpcomingEvents(MoodleSession session);

  /// إشعارات الحساب الأخيرة.
  Future<List<NotificationDto>> fetchNotifications(MoodleSession session);

  /// تسليم إجابة نصية (نص مباشر).
  Future<void> submitText(
    MoodleSession session,
    int assignmentMoodleId,
    String text,
  );

  /// تسليم ملفات (مع إجابة نصية اختيارية) — يرفع لمنطقة Draft ثم يحفظ.
  Future<void> submitFiles(
    MoodleSession session,
    int assignmentMoodleId,
    List<String> filePaths, {
    String? text,
  });
}
