import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/assignments_dao.dart';
import 'daos/content_dao.dart';
import 'daos/extras_daos.dart';
import 'daos/sync_queue_dao.dart';
import 'database_provider.dart';

/// حزمة جميع الـ DAOs في مكان واحد — تُقرأ من المحرك والواجهات.
class Daos {
  Daos(this.db)
      : content = ContentDao(db),
        assignments = AssignmentsDao(db),
        queue = SyncQueueDao(db),
        calendar = CalendarDao(db),
        notifications = NotificationsDao(db),
        files = DownloadedFilesDao(db);

  final AppDatabase db;
  final ContentDao content;
  final AssignmentsDao assignments;
  final SyncQueueDao queue;
  final CalendarDao calendar;
  final NotificationsDao notifications;
  final DownloadedFilesDao files;
}

/// مزوّد الحزمة المرتبط بقاعدة البيانات (القفل مسؤولية databaseProvider).
final daosProvider = Provider<Daos>(
  (ref) => Daos(ref.watch(databaseProvider)),
);

/// حذف كل بيانات حساب من قاعدة البيانات (عند حذف الحساب من الجهاز).
///
/// محميّ try/catch: فشل التنظيف (بيئة اختبار بلا SQLite مثلاً) لا يمنع
/// حذف الحساب نفسه.
Future<void> purgeAccountData(AppDatabase db, String accountId) async {
  try {
    final daos = Daos(db);
    await daos.content.purgeAccount(accountId);
    await daos.assignments.purgeAccount(accountId);
    await daos.queue.purgeAccount(accountId);
    await daos.calendar.purgeAccount(accountId);
    await daos.notifications.purgeAccount(accountId);
    await daos.files.purgeAccount(accountId);
  } catch (_) {
    // تنظيف فاشل → نكمل حذف الحساب من مخزن الحسابات والتوكن.
    return;
  }
}
