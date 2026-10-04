/// تصنيف استعجال الواجبات — منطق نقري قابل للاختبار (بلا واجهات).
///
/// يُستخدم في بطاقة الواجب وودجت «مهام اليوم» وفلاتر العرض:
/// • done: سُلِّم (محلياً في الطابور أو على الخادم) أو مُقيَّم.
/// • overdue: الموعد مضى ولم يُسلَّم.
/// • dueSoon: يستحق خلال 24 ساعة القادمة.
/// • upcoming: يستحق بعد 24 ساعة.
/// • noDate: بلا موعد محدد.
import '../../../core/db/app_database.dart';

enum AssignmentUrgency { done, overdue, dueSoon, upcoming, noDate }

/// يحدّد فئة استعجال واجب واحد في لحظة معيّنة.
AssignmentUrgency classifyAssignment(
  Assignment assignment, {
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();

  // محفوظ في الطابور = الطالب سلّم من وجهة نظره (سيُرفع تلقائياً).
  if (assignment.pendingSync ||
      assignment.status == 'submitted' ||
      assignment.status == 'graded') {
    return AssignmentUrgency.done;
  }

  final due = assignment.dueAt;
  if (due == null) return AssignmentUrgency.noDate;
  if (due.isBefore(moment)) return AssignmentUrgency.overdue;
  if (due.difference(moment) <= const Duration(hours: 24)) {
    return AssignmentUrgency.dueSoon;
  }
  return AssignmentUrgency.upcoming;
}

/// هل الواجب من فئة «مهام اليوم» (متأخر أو يستحق خلال 24 ساعة)؟
bool isTodayTask(Assignment assignment, {DateTime? now}) {
  final urgency = classifyAssignment(assignment, now: now);
  return urgency == AssignmentUrgency.overdue ||
      urgency == AssignmentUrgency.dueSoon;
}
