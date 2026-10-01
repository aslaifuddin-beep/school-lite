import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/db/app_database.dart';

/// إنشاء قاعدة اختبار في الذاكرة (SQLite في عملية الاختبار نفسها).
AppDatabase createTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// فتح قاعدة اختبار مع التأكد أن sqlite3 يعمل فعلياً على هذه الآلة.
///
/// على بعض أجهزة Windows لا تتوفر sqlite3.dll للاختبارات المكتبية —
/// عندها تُتخطّى اختبارات القاعدة برسالة واضحة بدل الفشل المربك.
Future<AppDatabase?> openTestDbOrNull() async {
  try {
    final db = createTestDb();
    await db.customSelect('select 1').get();
    return db;
  } catch (_) {
    return null;
  }
}

/// تخطي الاختبار الحالي إن كانت sqlite3 غير متاحة.
void skipWithoutSqlite() {
  markTestSkipped('sqlite3 غير متوفرة على هذه الآلة — تخطّي اختبار القاعدة');
}
