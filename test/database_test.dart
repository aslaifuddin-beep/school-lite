import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/core/db/daos.dart';
import 'package:school_lite/core/db/daos/assignments_dao.dart';
import 'package:school_lite/core/db/daos/content_dao.dart';
import 'package:school_lite/core/db/daos/sync_queue_dao.dart';
import 'package:school_lite/core/network/content_source.dart';
import 'package:school_lite/core/network/dto.dart';
import 'package:school_lite/features/sync/application/submission_service.dart';

import 'helpers/db_test_helpers.dart';

/// اختبارات قاعدة البيانات المحلية (Drift) والـ DAOs وعزل الحسابات.
///
/// كل اختبار يعمل داخل withDb: إن لم تتوفر sqlite3 على الآلة يُتخطّى
/// بهدوء بدل أن يفشل اختبار بقية الحزمة.
Future<void> withDb(Future<void> Function(AppDatabase db) body) async {
  final db = await openTestDbOrNull();
  if (db == null) {
    skipWithoutSqlite();
    return;
  }
  try {
    await body(db);
  } finally {
    await db.close();
  }
}

void main() {
  group('المقررات والأقسام (ContentDao)', () {
    test('استبدال مقرر يبني الأقسام والوحدات ويزيل القديم', () async {
      await withDb((db) async {
        final content = ContentDao(db);

        await content.replaceCourse(
          accountId: 'a1',
          course: const CourseDto(id: 101, fullName: 'رياضيات'),
          bundles: [
            SectionBundleDto(
              section: const SectionDto(id: 1, title: 'الوحدة الأولى'),
              modules: const [
                ModuleDto(id: 11, name: 'درس المقادير'),
                ModuleDto(id: 12, name: 'ملزمة التمارين'),
              ],
            ),
          ],
        );

        final courses = await content.watchCourses('a1').first;
        expect(courses, hasLength(1));
        expect(courses.single.fullName, 'رياضيات');

        final sections = await content.watchSections('a1', 'a1:101').first;
        expect(sections, hasLength(1));
        expect(sections.single.title, 'الوحدة الأولى');

        final modules = await content.watchModules('a1', 'a1:1').first;
        expect(modules, hasLength(2));
        expect(modules.first.name, 'درس المقادير');
        expect(modules.first.orderIndex, 0);

        // استبدال لاحق بلا أقسام يزيل أقسام المقرر القديمة وحدها.
        await content.replaceCourse(
          accountId: 'a1',
          course: const CourseDto(id: 101, fullName: 'رياضيات'),
          bundles: const [],
        );
        expect(await content.watchSections('a1', 'a1:101').first, isEmpty);
        expect(await content.watchCourses('a1').first, hasLength(1));
      });
    });

    test('نفس معرّف Moodle لحسابين يبقى معزولاً تماماً', () async {
      await withDb((db) async {
        final content = ContentDao(db);

        for (final accountId in ['alice', 'bob']) {
          await content.replaceCourse(
            accountId: accountId,
            course: const CourseDto(id: 101, fullName: 'كيمياء'),
            bundles: [
              SectionBundleDto(
                section: const SectionDto(id: 7, title: 'فصل'),
                modules: const [ModuleDto(id: 70, name: 'درس')],
              ),
            ],
          );
        }

        expect(await content.watchCourses('alice').first, hasLength(1));
        expect(await content.watchCourses('bob').first, hasLength(1));
        expect(
          (await content.watchCourses('alice').first).single.id,
          'alice:101',
        );

        // حذف حساب واحد لا يمسّ الآخر.
        await purgeAccountData(db, 'alice');
        expect(await content.watchCourses('alice').first, isEmpty);
        expect(await content.watchCourses('bob').first, hasLength(1));
        expect(await content.watchModules('bob', 'bob:7').first, hasLength(1));
      });
    });
  });

  group('الواجبات (AssignmentsDao)', () {
    test('الحالة المحلية المعلّقة تنجو من مزامنة الخادم', () async {
      await withDb((db) async {
        final dao = AssignmentsDao(db);
        const dto = AssignmentDto(id: 501, courseMoodleId: 101, name: 'واجب');

        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [dto],
        );
        await dao.setPending(
          accountId: 'a1',
          assignmentMoodleId: 501,
          pending: true,
          onlineText: 'إجابتي المحفوظة',
        );

        // مزامنة تالية: نفس الواجب بحالة غير معلنة من الخادم.
        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [dto],
        );

        final row = await dao.byMoodleId('a1', 501);
        expect(row, isNotNull);
        expect(row!.status, 'queued');
        expect(row.pendingSync, isTrue);
        expect(row.onlineText, 'إجابتي المحفوظة');
      });
    });

    test('applyStatus لا يلمس واجباً معلّقاً في الطابور', () async {
      await withDb((db) async {
        final dao = AssignmentsDao(db);

        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [
            AssignmentDto(id: 502, courseMoodleId: 101, name: 'تقرير'),
          ],
        );
        await dao.setPending(
          accountId: 'a1',
          assignmentMoodleId: 502,
          pending: true,
        );

        await dao.applyStatus(
          accountId: 'a1',
          assignmentMoodleId: 502,
          status: const SubmissionStatusDto(status: 'notsubmitted'),
        );

        final row = await dao.byMoodleId('a1', 502);
        expect(row!.status, 'queued');

        // بعد رفع الطابور تُقبل حالة الخادم عادية.
        await dao.setStatusById(
          accountId: 'a1',
          assignmentMoodleId: 502,
          status: 'submitted',
          clearPending: true,
          submittedAt: DateTime.now(),
        );
        await dao.applyStatus(
          accountId: 'a1',
          assignmentMoodleId: 502,
          status: const SubmissionStatusDto(status: 'submitted'),
        );
        final updated = await dao.byMoodleId('a1', 502);
        expect(updated!.status, 'submitted');
        expect(updated.pendingSync, isFalse);
      });
    });

    test('الواجبات الملغاة من الخادم تُحذف ما لم تكن معلّقة', () async {
      await withDb((db) async {
        final dao = AssignmentsDao(db);

        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [
            AssignmentDto(id: 1, courseMoodleId: 101, name: 'محذوف لاحقاً'),
            AssignmentDto(id: 2, courseMoodleId: 101, name: 'معلّق'),
          ],
        );
        await dao.setPending(
          accountId: 'a1',
          assignmentMoodleId: 2,
          pending: true,
        );

        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [],
        );

        expect(await dao.byMoodleId('a1', 1), isNull);
        final kept = await dao.byMoodleId('a1', 2);
        expect(kept, isNotNull);
        expect(kept!.pendingSync, isTrue);
      });
    });
  });

  group('طابور المزامنة (SyncQueueDao)', () {
    test('enqueue ثم due ثم markSent', () async {
      await withDb((db) async {
        final queue = SyncQueueDao(db);

        final id = await queue.enqueue(
          accountId: 'a1',
          payload: const SubmissionPayload(
            assignmentMoodleId: 501,
            text: 'جواب',
          ),
        );

        final due = await queue.dueEntries(accountId: 'a1');
        expect(due, hasLength(1));
        expect(due.single.id, id);

        final decoded = queue.decodePayload(due.single.payload);
        expect(decoded.assignmentMoodleId, 501);
        expect(decoded.text, 'جواب');

        expect(await queue.pendingCount('a1').first, 1);
        await queue.markSent(id);
        expect(await queue.dueEntries(accountId: 'a1'), isEmpty);
        expect(await queue.pendingCount('a1').first, 0);
      });
    });

    test('خطأ شبكة يبقى جاهزاً فوراً، وخطأ خادم يؤجّل بbackoff', () async {
      await withDb((db) async {
        final queue = SyncQueueDao(db);

        final networkId = await queue.enqueue(
          accountId: 'a1',
          payload: const SubmissionPayload(assignmentMoodleId: 1),
        );
        final serverId = await queue.enqueue(
          accountId: 'a1',
          payload: const SubmissionPayload(assignmentMoodleId: 2),
        );

        await queue.markFailed(
          id: networkId,
          error: 'بلا شبكة',
          isNetwork: true,
          retryCount: 0,
        );
        await queue.markFailed(
          id: serverId,
          error: 'رفض الخادم',
          isNetwork: false,
          retryCount: 0,
        );

        final now = DateTime.now();
        final immediate = await queue.dueEntries(accountId: 'a1', now: now);
        // خطأ الشبكة: متاح فوراً. خطأ الخادم: مؤجّل (+60s) فلا يظهر الآن.
        expect(immediate.map((e) => e.id), contains(networkId));
        expect(immediate.map((e) => e.id), isNot(contains(serverId)));

        final later = await queue.dueEntries(
          accountId: 'a1',
          now: now.add(const Duration(minutes: 2)),
        );
        expect(later.map((e) => e.id), contains(serverId));
        expect(later.singleWhere((e) => e.id == serverId).retryCount, 1);
        expect(
          later.singleWhere((e) => e.id == networkId).status,
          'pending',
        );
      });
    });
  });

  group('خدمة التسليم (SubmissionService)', () {
    test('حفظ نص ينشئ طابوراً ويعلّم الواجب في معاملة واحدة', () async {
      await withDb((db) async {
        final dao = AssignmentsDao(db);
        final queue = SyncQueueDao(db);
        final service = SubmissionService(db);

        await dao.replaceCourseAssignments(
          accountId: 'a1',
          courseMoodleId: 101,
          dtos: const [
            AssignmentDto(id: 501, courseMoodleId: 101, name: 'واجب'),
          ],
        );

        await service.saveTextSubmission(
          accountId: 'a1',
          assignmentMoodleId: 501,
          text: 'حللت التمارين كلها',
        );

        final row = await dao.byMoodleId('a1', 501);
        expect(row!.status, 'queued');
        expect(row.pendingSync, isTrue);
        expect(row.onlineText, 'حللت التمارين كلها');

        final due = await queue.dueEntries(accountId: 'a1');
        expect(due, hasLength(1));
        expect(queue.decodePayload(due.single.payload).text, 'حللت التمارين كلها');

        await expectLater(
          service.saveTextSubmission(
            accountId: 'a1',
            assignmentMoodleId: 501,
            text: '   ',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });

  group('تنظيف الحساب المحذوف (purgeAccountData)', () {
    test('يحذف كل صفوف الحساب ولا يمسّ حساباً آخر', () async {
      await withDb((db) async {
        final content = ContentDao(db);
        final assignments = AssignmentsDao(db);
        final queue = SyncQueueDao(db);

        for (final accountId in ['gone', 'stays']) {
          await content.replaceCourse(
            accountId: accountId,
            course: const CourseDto(id: 101, fullName: 'مادة'),
            bundles: const [],
          );
          await assignments.replaceCourseAssignments(
            accountId: accountId,
            courseMoodleId: 101,
            dtos: const [
              AssignmentDto(id: 5, courseMoodleId: 101, name: 'واجب'),
            ],
          );
          await queue.enqueue(
            accountId: accountId,
            payload: const SubmissionPayload(assignmentMoodleId: 5),
          );
        }

        await purgeAccountData(db, 'gone');

        expect(await content.watchCourses('gone').first, isEmpty);
        expect(await assignments.byMoodleId('gone', 5), isNull);
        expect(await queue.dueEntries(accountId: 'gone'), isEmpty);

        expect(await content.watchCourses('stays').first, hasLength(1));
        expect(await assignments.byMoodleId('stays', 5), isNotNull);
        expect(await queue.dueEntries(accountId: 'stays'), hasLength(1));
      });
    });
  });
}
