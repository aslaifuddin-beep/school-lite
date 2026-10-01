import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/core/db/daos/assignments_dao.dart';
import 'package:school_lite/core/db/daos/sync_queue_dao.dart';
import 'package:school_lite/core/db/database_provider.dart';
import 'package:school_lite/core/network/connectivity.dart';
import 'package:school_lite/core/network/content_source.dart';
import 'package:school_lite/core/network/demo_content_source.dart';
import 'package:school_lite/core/network/dto.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';
import 'package:school_lite/features/accounts/domain/account.dart';
import 'package:school_lite/features/sync/application/submission_service.dart';
import 'package:school_lite/features/sync/application/sync_controller.dart';
import 'package:school_lite/features/sync/application/sync_engine.dart';
import 'package:school_lite/features/sync/application/sync_providers.dart';

import 'helpers/db_test_helpers.dart';
import 'helpers/test_helpers.dart';

/// حساب تجريبي مباشر (بلا Riverpod) لاختبارات المحرك.
Account demoAccount({String id = 'acc_demo'}) => Account(
      id: id,
      serverUrl: 'https://demo.moodle.net',
      username: 'demo',
      displayName: 'طالب تجريبي',
      isDemo: true,
      colorIndex: 0,
      sortOrder: 0,
      createdAt: DateTime.now(),
    );

const demoSession = MoodleSession(
  baseUrl: 'https://demo.moodle.net',
  token: 'demo',
  userId: 7,
);

/// مصدر «بلا شبكة» — كل نداء يرمي خطأ شبكة.
class OfflineSource implements ContentSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const MoodleSourceException('بلا شبكة', isNetwork: true);
}

/// اتصال وهمي «متصل دائماً» للاختبارات (بلا منصة أصلية).
class FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('محرك المزامنة (Demo)', () {
    test('مزامنة تجريبية تملأ كل الجداول وتعيد نتيجة ناجحة', () async {
      final db = await openTestDbOrNull();
      if (db == null) {
        skipWithoutSqlite();
        return;
      }
      addTearDown(db.close);

      final engine = SyncEngine(
        db: db,
        source: DemoContentSource(latency: Duration.zero),
      );
      final result = await engine.syncAccount(demoAccount(), demoSession);

      expect(result.ok, isTrue);
      expect(result.coursesCount, 4);
      expect(result.assignmentsCount, 6);
      expect(result.eventsCount, 3);
      expect(result.notificationsCount, 3);

      final courses = await db.select(db.courses).get();
      expect(courses, hasLength(4));
      final assignments = await db.select(db.assignments).get();
      expect(assignments, hasLength(6));
      final sections = await db.select(db.courseSections).get();
      expect(sections, hasLength(8));
      final events = await db.select(db.calendarEvents).get();
      expect(events, hasLength(3));
      final notifications = await db.select(db.localNotifications).get();
      expect(notifications, hasLength(3));
    });

    test('انقطاع الشبكة عند الجلب يُرجع offline بلا كتابة', () async {
      final db = await openTestDbOrNull();
      if (db == null) {
        skipWithoutSqlite();
        return;
      }
      addTearDown(db.close);

      final engine = SyncEngine(db: db, source: OfflineSource());
      final result = await engine.syncAccount(demoAccount(), demoSession);

      expect(result.ok, isFalse);
      expect(result.offline, isTrue);
      expect(await db.select(db.courses).get(), isEmpty);
    });

    test('واجب معلّق في الطابور ينجو من المزامنة التالية', () async {
      final db = await openTestDbOrNull();
      if (db == null) {
        skipWithoutSqlite();
        return;
      }
      addTearDown(db.close);

      final engine = SyncEngine(
        db: db,
        source: DemoContentSource(latency: Duration.zero),
      );
      final account = demoAccount();
      await engine.syncAccount(account, demoSession);

      // الطالب يحفظ إجابة ثم لا شبكة: الواجب يصبح معلّقاً.
      await SubmissionService(db).saveTextSubmission(
        accountId: account.id,
        assignmentMoodleId: 501,
        text: 'إجابة قيد الانتظار',
      );

      // مزامنة تالية (عادت الشبكة لكن رفع الطابور فشل/تأجل) → ينجو التعلّق.
      await engine.syncAccount(account, demoSession);

      final row =
          await AssignmentsDao(db).byMoodleId(account.id, 501);
      expect(row, isNotNull);
      expect(row!.pendingSync, isTrue);
      expect(row.status, 'queued');
      expect(row.onlineText, 'إجابة قيد الانتظار');
    });
  });

  group('معالجة الطابور (QueueProcessor)', () {
    test('تسليم نصي يُرفع فوراً في الوضع التجريبي ويُصفّي الطابور', () async {
      final db = await openTestDbOrNull();
      if (db == null) {
        skipWithoutSqlite();
        return;
      }
      addTearDown(db.close);

      final account = demoAccount();
      final engine = SyncEngine(
        db: db,
        source: DemoContentSource(latency: Duration.zero),
      );
      await engine.syncAccount(account, demoSession);

      await SubmissionService(db).saveTextSubmission(
        accountId: account.id,
        assignmentMoodleId: 503,
        text: 'حل التحليل كامل',
      );

      final processed = await engine.processQueue(
        account,
        demoSession,
      );
      expect(processed.sent, 1);
      expect(processed.failed, 0);
      expect(processed.offline, isFalse);

      final queue = SyncQueueDao(db);
      expect(await queue.dueEntries(accountId: account.id), isEmpty);

      final row = await AssignmentsDao(db).byMoodleId(account.id, 503);
      expect(row!.status, 'submitted');
      expect(row.pendingSync, isFalse);
      expect(row.submittedAt, isNotNull);
    });

    test('فشل شبكة أثناء الرفع يوقف الدفعة ويبقي المدخل جاهزاً', () async {
      final db = await openTestDbOrNull();
      if (db == null) {
        skipWithoutSqlite();
        return;
      }
      addTearDown(db.close);

      final account = demoAccount();
      // إنشاء واجب محلياً دون مزامنة (بلا خادم).
      await AssignmentsDao(db).replaceCourseAssignments(
        accountId: account.id,
        courseMoodleId: 101,
        dtos: const [
          AssignmentDto(id: 900, courseMoodleId: 101, name: 'واجب محلي'),
        ],
      );
      await SubmissionService(db).saveTextSubmission(
        accountId: account.id,
        assignmentMoodleId: 900,
        text: 'جواب',
      );

      final processor = QueueProcessor(
        db: db,
        source: OfflineSource(),
        queue: SyncQueueDao(db),
      );
      final result = await processor.process(
        account: account,
        session: demoSession,
      );

      expect(result.offline, isTrue);
      expect(result.sent, 0);
      expect(result.failed, 1);

      final queue = SyncQueueDao(db);
      final remaining = await queue.dueEntries(accountId: account.id);
      expect(remaining, hasLength(1));
      expect(remaining.single.status, 'pending');
      expect(remaining.single.retryCount, 1);

      // الواجب ما زال معلّقاً — لا فقدان بيانات.
      final row = await AssignmentsDao(db).byMoodleId(account.id, 900);
      expect(row!.pendingSync, isTrue);
      expect(row.status, 'queued');
    });
  });

  group('متحكّم المزامنة (SyncController)', () {
    test('مزامنة يدوية تملأ قاعدة البيانات وتُحدّث الحالة', () async {
      final prefs = await mockPrefs();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          ...baseOverrides(prefs),
          databaseProvider.overrideWithValue(db),
          connectivityServiceProvider.overrideWithValue(FakeConnectivity()),
          contentSourceFactoryProvider
              .overrideWithValue((_) => DemoContentSource(latency: Duration.zero)),
        ],
      );
      addTearDown(container.dispose);

      await addDemoAccount(container, name: 'طالب');

      await container.read(syncControllerProvider.notifier).syncNow();

      final state = container.read(syncControllerProvider);
      expect(state.phase, SyncPhase.idle);
      expect(state.lastSyncedAt, isNotNull);
      expect(state.lastError, isNull);

      // المقررات والواجبات متاحة الآن من Streams القاعدة.
      final courses = await container.read(coursesProvider.future);
      expect(courses, hasLength(4));
      final assignments = await container.read(assignmentsProvider.future);
      expect(assignments, hasLength(6));
      expect(assignments.first.dueAt, isNotNull);

      // آخر مزامنة حُفظت في الحساب.
      expect(
        container.read(activeAccountProvider)?.lastSyncedAt,
        isNotNull,
      );
    });
  });
}
