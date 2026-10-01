import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// مخطط قاعدة البيانات المحلية (Drift/SQLite) — المحرك يعمل بدون إنترنت.
//
// قاعدة واحدة للجهاز، وكل صف محتوى يحمل accountId لعزل بيانات كل طالب.
// معرّف الصفوف (id) مركّب بصيغة "accountId:moodleId" لضمان العزل التام
// حتى لو تساوى معرّف Moodle بين حسابين.
// ---------------------------------------------------------------------------

/// مقررات الطالب المسجّل فيها.
@DataClassName('Course')
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  IntColumn get moodleId => integer()();
  TextColumn get fullName => text()();
  TextColumn get shortName => text().withDefault(const Constant(''))();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get progress => real().nullable()();
  IntColumn get enrolledCount => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// أقسام المقرر (وحدات/فصول).
@DataClassName('CourseSection')
class CourseSections extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get courseId => text()(); // → Courses.id
  IntColumn get moodleId => integer()();
  TextColumn get title => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// وحدات/عناصر داخل القسم: دروس، ملفات، روابط، واجبات…
@DataClassName('CourseModule')
class CourseModules extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get courseId => text()();
  TextColumn get sectionId => text()();
  IntColumn get moodleId => integer()();
  TextColumn get name => text()();
  /// نوع العنصر: resource / url / page / assign / forum / label …
  TextColumn get modType => text().withDefault(const Constant('resource'))();
  TextColumn get intro => text().withDefault(const Constant(''))();
  TextColumn get externalUrl => text().nullable()();
  /// رابط الملف المباشر (pluginfile) للتنزيل لاحقاً.
  TextColumn get fileUrl => text().nullable()();
  TextColumn get filename => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  BoolColumn get available => boolean().withDefault(const Constant(true))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// الواجبات — حالة التسليم محفوظة محلياً (تعمل بدون إنترنت).
@DataClassName('Assignment')
class Assignments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get courseId => text()();
  IntColumn get moodleId => integer()();
  TextColumn get name => text()();
  TextColumn get intro => text().withDefault(const Constant(''))();
  /// موعد التسليم (null = بلا موعد محدد).
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get submissionsFrom => dateTime().nullable()();
  BoolColumn get allowLateSubmit => boolean().withDefault(const Constant(true))();

  /// not_submitted | queued | submitted | graded
  TextColumn get status => text().withDefault(const Constant('not_submitted'))();
  /// true إذا كان هناك إرسال محفوظ في طابور المزامنة ولم يُرفع بعد.
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  TextColumn get onlineText => text().nullable()();
  TextColumn get gradeText => text().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// طابور المزامنة (Sync Queue) — التسليمات القادمة من وضع عدم الاتصال.
@DataClassName('SyncQueueEntry')
class SyncQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  /// submit_assignment | … (أنواع أخرى لاحقاً)
  TextColumn get type => text()();
  /// حمولة JSON: الإجابة/المسارات/معرف الواجب.
  TextColumn get payload => text()();
  /// pending | sending | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// الملفات المحفوظة محلياً (المواد والمتعلقات).
@DataClassName('DownloadedFile')
class DownloadedFiles extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get localPath => text()();
  TextColumn get filename => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  /// queued | downloading | done | failed
  TextColumn get status => text().withDefault(const Constant('queued'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// إشعارات التطبيق لكل حساب على حدة.
@DataClassName('LocalNotification')
class LocalNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get contextUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// مواعيد التقويم والإجراءات القادمة.
@DataClassName('CalendarEvent')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  IntColumn get moodleId => integer()();
  TextColumn get name => text()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  IntColumn get courseMoodleId => integer().nullable()();
  TextColumn get courseName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
