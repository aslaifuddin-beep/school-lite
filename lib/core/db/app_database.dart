import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// قاعدة البيانات المحلية الشاملة (Drift/SQLite) — قلب الـ Offline-First.
///
/// كل محتوى تعليمي (مقررات، أقسام، وحدات، واجبات، طابور، ملفات، إشعارات،
/// تقويم) يُخزَّن هنا داخل معاملات ذرّية، وتُقرأ الواجهات من Streams
/// تُحدَّث تلقائياً عند أي تغيير.
///
/// ملاحظة: بيانات «الحسابات» نفسها تبقى في SharedPreferences (أسرع إقلاع،
/// قراءة متزامنة عند التشغيل) بينما كل محتوى الطالب هنا مربوط بـ accountId.
@DriftDatabase(tables: [
  Courses,
  CourseSections,
  CourseModules,
  Assignments,
  SyncQueueEntries,
  DownloadedFiles,
  LocalNotifications,
  CalendarEvents,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// للاختبارات: قاعدة في الذاكرة بلا ملفات.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// فتح الملف في خيط منفصل (isolate) — لا يعيق الإقلاع البارد إطلاقاً.
QueryExecutor _openConnection() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'school_lite_v1.db'));
      return NativeDatabase.createInBackground(file);
    });
