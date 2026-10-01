import 'package:drift/drift.dart';

import '../../network/dto.dart';
import '../app_database.dart';
import '../row_ids.dart';

/// DAO المقررات والأقسام والوحدات — الكتابة الذرّية داخل transaction واحدة:
/// إما تُحدَّث كل بيانات المقرر أو لا يتغير شيء.
class ContentDao {
  ContentDao(this.db);

  final AppDatabase db;

  // --------------------------------------------------------------- القراءة
  /// مقررات الحساب مرتبة بالاسم (Stream يتحدث تلقائياً عند أي تغيير).
  Stream<List<Course>> watchCourses(String accountId) {
    final query = db.select(db.courses)
      ..where((t) => t.accountId.equals(accountId));
    return query.watch().map((rows) {
      final sorted = [...rows]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return sorted;
    });
  }

  /// أقسام مقرر واحد مع ترتيب الظهور.
  Stream<List<CourseSection>> watchSections(
    String accountId,
    String courseId,
  ) {
    final query = db.select(db.courseSections)
      ..where((t) => t.accountId.equals(accountId) & t.courseId.equals(courseId));
    return query.watch().map((rows) {
      final sorted = [...rows]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return sorted;
    });
  }

  /// وحدات قسم واحد مرتبة.
  Stream<List<CourseModule>> watchModules(
    String accountId,
    String sectionId,
  ) {
    final query = db.select(db.courseModules)
      ..where(
        (t) => t.accountId.equals(accountId) & t.sectionId.equals(sectionId),
      );
    return query.watch().map((rows) {
      final sorted = [...rows]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return sorted;
    });
  }

  /// كل وحدات المقرر (للتبويب/للتخطيط السريع).
  Future<List<CourseModule>> modulesOfCourse(
    String accountId,
    String courseId,
  ) {
    final query = db.select(db.courseModules)
      ..where((t) => t.accountId.equals(accountId) & t.courseId.equals(courseId));
    return query.get();
  }

  // --------------------------------------------------------------- الكتابة
  /// استبدال بيانات مقرر كاملة (مقرّر + أقسامه + وحداته) ذرياً.
  Future<void> replaceCourse({
    required String accountId,
    required CourseDto course,
    required List<SectionBundleDto> bundles,
  }) {
    final courseId = rowId(accountId, course.id);
    return db.transaction(() async {
      // حذف المحتوى القديم لهذا المقرر فقط (لا يمسّ حسابات أخرى).
      await (db.delete(db.courseModules)
            ..where((t) => t.accountId.equals(accountId) & t.courseId.equals(courseId)))
          .go();
      await (db.delete(db.courseSections)
            ..where((t) => t.accountId.equals(accountId) & t.courseId.equals(courseId)))
          .go();

      await _upsertCourse(accountId, course, courseId);

      for (final bundle in bundles) {
        final section = bundle.section;
        if (section.id == 0) continue;
        final sectionRowId = rowId(accountId, section.id);
        await db.into(db.courseSections).insert(
              CourseSectionsCompanion.insert(
                id: sectionRowId,
                accountId: accountId,
                courseId: courseId,
                moodleId: section.id,
                title: section.title,
                summary: Value(section.summary),
                orderIndex: Value(section.orderIndex),
                visible: Value(section.visible),
              ),
              mode: InsertMode.insertOrReplace,
            );
        for (final module in bundle.modules) {
          if (module.id == 0) continue;
          await db.into(db.courseModules).insert(
                CourseModulesCompanion.insert(
                  id: rowId(accountId, module.id),
                  accountId: accountId,
                  courseId: courseId,
                  sectionId: sectionRowId,
                  moodleId: module.id,
                  name: module.name,
                  modType: Value(module.modType),
                  intro: Value(module.intro),
                  externalUrl: Value(module.externalUrl),
                  fileUrl: Value(module.fileUrl),
                  filename: Value(module.filename),
                  fileSize: Value(module.fileSize),
                  orderIndex: Value(module.orderIndex),
                  available: Value(module.available),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      }
    });
  }

  Future<void> _upsertCourse(
    String accountId,
    CourseDto course,
    String courseId,
  ) async {
    await db.into(db.courses).insert(
          CoursesCompanion.insert(
            id: courseId,
            accountId: accountId,
            moodleId: course.id,
            fullName: course.fullName,
            shortName: Value(course.shortName),
            summary: Value(course.summary),
            imageUrl: Value(course.imageUrl),
            progress: Value(course.progress),
            enrolledCount: Value(course.enrolledCount),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// مزامنة دفعة مقررات (تحديث بيانات المقررات نفسها دون لمس أقسامها).
  Future<void> upsertCourses(
    String accountId,
    List<CourseDto> courses,
  ) async {
    for (final course in courses) {
      await _upsertCourse(accountId, course, rowId(accountId, course.id));
    }
  }

  /// تنظيف كل محتوى حساب (عند حذف الحساب من الجهاز).
  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.courseModules)..where((t) => t.accountId.equals(accountId))).go();
    await (db.delete(db.courseSections)..where((t) => t.accountId.equals(accountId))).go();
    await (db.delete(db.courses)..where((t) => t.accountId.equals(accountId))).go();
  }
}
