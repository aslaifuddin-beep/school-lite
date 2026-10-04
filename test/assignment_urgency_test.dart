import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/features/assignments/domain/assignment_urgency.dart';

Assignment _assignment({
  DateTime? dueAt,
  bool pendingSync = false,
  String status = 'not_submitted',
}) {
  final now = DateTime.now();
  return Assignment(
    id: 'acc-1:10',
    accountId: 'acc-1',
    courseId: 'acc-1:5',
    moodleId: 10,
    name: 'واجب تجريبي',
    intro: '',
    dueAt: dueAt,
    allowLateSubmit: true,
    status: status,
    pendingSync: pendingSync,
    updatedAt: now,
  );
}

void main() {
  final now = DateTime(2026, 10, 4, 12);

  group('classifyAssignment', () {
    test('بلا موعد ← noDate', () {
      expect(
        classifyAssignment(_assignment(), now: now),
        AssignmentUrgency.noDate,
      );
    });

    test('موعد مضى ← overdue', () {
      final a = _assignment(dueAt: now.subtract(const Duration(hours: 1)));
      expect(classifyAssignment(a, now: now), AssignmentUrgency.overdue);
    });

    test('يستحق خلال 24 ساعة ← dueSoon', () {
      final a = _assignment(dueAt: now.add(const Duration(hours: 23)));
      expect(classifyAssignment(a, now: now), AssignmentUrgency.dueSoon);
    });

    test('بعد 24 ساعة ← upcoming', () {
      final a = _assignment(dueAt: now.add(const Duration(hours: 25)));
      expect(classifyAssignment(a, now: now), AssignmentUrgency.upcoming);
    });

    test('متأخر لكن pendingSync ← done (محلياً سُلِّم)', () {
      final a = _assignment(
        dueAt: now.subtract(const Duration(days: 1)),
        pendingSync: true,
      );
      expect(classifyAssignment(a, now: now), AssignmentUrgency.done);
    });

    test('status=submitted أو graded ← done', () {
      expect(
        classifyAssignment(
          _assignment(dueAt: now.add(const Duration(hours: 1)), status: 'submitted'),
          now: now,
        ),
        AssignmentUrgency.done,
      );
      expect(
        classifyAssignment(
          _assignment(status: 'graded'),
          now: now,
        ),
        AssignmentUrgency.done,
      );
    });
  });

  group('isTodayTask', () {
    test('يشمل المتأخر والقريب فقط', () {
      expect(
        isTodayTask(
          _assignment(dueAt: now.subtract(const Duration(hours: 5))),
          now: now,
        ),
        isTrue,
      );
      expect(
        isTodayTask(
          _assignment(dueAt: now.add(const Duration(hours: 10))),
          now: now,
        ),
        isTrue,
      );
      expect(
        isTodayTask(
          _assignment(dueAt: now.add(const Duration(days: 3))),
          now: now,
        ),
        isFalse,
      );
      expect(isTodayTask(_assignment(), now: now), isFalse);
      expect(
        isTodayTask(_assignment(dueAt: now, pendingSync: true), now: now),
        isFalse,
      );
    });
  });
}
