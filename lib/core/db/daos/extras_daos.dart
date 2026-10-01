import 'package:drift/drift.dart';

import '../../network/dto.dart';
import '../app_database.dart';
import '../row_ids.dart';

/// DAO التقويم — استبدال مواعيد الحساب بالكامل من الخادم ثم مراقبتها.
class CalendarDao {
  CalendarDao(this.db);

  final AppDatabase db;

  /// مواعيد قادمة مرتبة من الأقرب إلى الأبعد.
  Stream<List<CalendarEvent>> watchUpcoming(String accountId) {
    final query = db.select(db.calendarEvents)
      ..where((t) => t.accountId.equals(accountId));
    return query.watch().map((rows) {
      final sorted = [...rows]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return sorted;
    });
  }

  Future<void> replaceAll({
    required String accountId,
    required List<CalendarEventDto> events,
  }) {
    return db.transaction(() async {
      await (db.delete(db.calendarEvents)
            ..where((t) => t.accountId.equals(accountId)))
          .go();
      final now = DateTime.now();
      for (final e in events) {
        await db.into(db.calendarEvents).insert(
              CalendarEventsCompanion.insert(
                id: rowId(accountId, e.id),
                accountId: accountId,
                moodleId: e.id,
                name: e.name,
                startsAt: e.startsAt,
                endsAt: Value(e.endsAt),
                courseMoodleId: Value(e.courseMoodleId),
                courseName: Value(e.courseName),
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.calendarEvents)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}

/// DAO إشعارات التطبيق (تُبنى محلياً من إشعارات Moodle + تذكيرات المواعيد).
class NotificationsDao {
  NotificationsDao(this.db);

  final AppDatabase db;

  /// الأحدث أولاً.
  Stream<List<LocalNotification>> watchAll(String accountId) {
    final query = db.select(db.localNotifications)
      ..where((t) => t.accountId.equals(accountId));
    return query.watch().map((rows) {
      final sorted = [...rows]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    });
  }

  /// عدد غير المقروء — لشارة التبويب.
  Stream<int> unreadCount(String accountId) {
    final query = db.select(db.localNotifications)
      ..where((t) => t.accountId.equals(accountId) & t.isRead.equals(false));
    return query.watch().map((rows) => rows.length);
  }

  /// دمج إشعارات جديدة من الخادم (المعرّف يمنع التكرار insertOrReplace).
  Future<void> merge({
    required String accountId,
    required List<NotificationDto> notifications,
  }) async {
    for (final n in notifications) {
      await db.into(db.localNotifications).insert(
            LocalNotificationsCompanion.insert(
              id: rowId(accountId, n.id),
              accountId: accountId,
              title: n.title,
              body: Value(n.body),
              contextUrl: Value(n.contextUrl),
              createdAt: n.createdAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  /// إضافة إشعار محلي (تذكير مثلاً) بمعرّف مُولَّد.
  Future<void> insertLocal({
    required String accountId,
    required String id,
    required String title,
    required String body,
    DateTime? createdAt,
    String? contextUrl,
  }) async {
    await db.into(db.localNotifications).insert(
          LocalNotificationsCompanion.insert(
            id: '${rowId(accountId, 0)}#$id',
            accountId: accountId,
            title: title,
            body: Value(body),
            contextUrl: Value(contextUrl),
            createdAt: createdAt ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> markAllRead(String accountId) async {
    await (db.update(db.localNotifications)
          ..where((t) => t.accountId.equals(accountId)))
        .write(const LocalNotificationsCompanion(isRead: Value(true)));
  }

  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.localNotifications)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}

/// DAO الملفات المحمّلة محلياً (المواد قابلة للاستخدام بلا إنترنت).
class DownloadedFilesDao {
  DownloadedFilesDao(this.db);

  final AppDatabase db;

  Stream<List<DownloadedFile>> watchAll(String accountId) {
    final query = db.select(db.downloadedFiles)
      ..where((t) => t.accountId.equals(accountId));
    return query.watch();
  }

  Future<DownloadedFile?> byId(String id) {
    final query = db.select(db.downloadedFiles)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// تسجيل/تحديث ملف بعد بدء التنزيل أو إنهائه.
  Future<void> upsert({
    required String accountId,
    required String id,
    required String sourceUrl,
    required String localPath,
    required String filename,
    int? fileSize,
    String? mimeType,
    String status = 'queued',
  }) async {
    await db.into(db.downloadedFiles).insert(
          DownloadedFilesCompanion.insert(
            id: id,
            accountId: accountId,
            sourceUrl: sourceUrl,
            localPath: localPath,
            filename: filename,
            fileSize: Value(fileSize),
            mimeType: Value(mimeType),
            status: Value(status),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> setStatus(String id, String status) async {
    await (db.update(db.downloadedFiles)..where((t) => t.id.equals(id))).write(
      DownloadedFilesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> purgeAccount(String accountId) async {
    await (db.delete(db.downloadedFiles)
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }
}
