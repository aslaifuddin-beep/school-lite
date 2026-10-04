import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/core/db/daos/extras_daos.dart';
import 'package:school_lite/core/network/dio_client.dart';
import 'package:school_lite/features/courses/data/file_download_service.dart';

import 'helpers/db_test_helpers.dart';

void main() {
  test('تنزيل ملف وحدة يحفظه محلياً ويعلّمه مُنزَّلاً', () async {
    final db = await openTestDbOrNull();
    if (db == null) {
      skipWithoutSqlite();
      return;
    }
    addTearDown(db.close);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response.add(List<int>.generate(2048, (i) => i % 256));
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));

    final temp = await Directory.systemTemp.createTemp('school_lite_dl');
    addTearDown(() => temp.delete(recursive: true));

    final client = DioClient();
    addTearDown(client.close);

    const module = CourseModule(
      id: 'acc:9',
      accountId: 'acc',
      courseId: 'acc:c',
      sectionId: 'acc:s',
      moodleId: 9,
      name: 'مذكرة',
      modType: 'resource',
      intro: '',
      fileUrl: null, // يُضبط أدناه بمنفذ الخادم الديناميكي
      filename: 'note.pdf',
      fileSize: 2048,
      orderIndex: 0,
      available: true,
      isDownloaded: false,
    );
    final moduleWithUrl = CourseModule(
      id: module.id,
      accountId: module.accountId,
      courseId: module.courseId,
      sectionId: module.sectionId,
      moodleId: module.moodleId,
      name: module.name,
      modType: module.modType,
      intro: module.intro,
      fileUrl: 'http://127.0.0.1:${server.port}/files/note.pdf',
      filename: module.filename,
      fileSize: module.fileSize,
      orderIndex: module.orderIndex,
      available: module.available,
      isDownloaded: module.isDownloaded,
    );
    await db.into(db.courseModules).insert(moduleWithUrl);

    final service = FileDownloadService(
      dio: client.dio,
      db: db,
      documentsDir: () async => temp,
    );

    final path = await service.downloadModule(
      accountId: 'acc',
      module: moduleWithUrl,
    );

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 2048);

    final record = await DownloadedFilesDao(db).byId(module.id);
    expect(record, isNotNull);
    expect(record!.status, 'downloaded');

    final updated = await (db.select(db.courseModules)
          ..where((t) => t.id.equals(module.id)))
        .getSingle();
    expect(updated.isDownloaded, isTrue);
    expect(updated.localPath, path);

    // إزالة التنزيل تحذف الملف وتُلغي التعليم.
    await service.removeDownload(accountId: 'acc', module: updated);
    expect(await file.exists(), isFalse);
    final cleared = await (db.select(db.courseModules)
          ..where((t) => t.id.equals(module.id)))
        .getSingle();
    expect(cleared.isDownloaded, isFalse);
    expect(
      (await DownloadedFilesDao(db).byId(module.id))!.status,
      'removed',
    );
  });

  test('فشل التنزيل ← status=failed ورمي الخطأ', () async {
    final db = await openTestDbOrNull();
    if (db == null) {
      skipWithoutSqlite();
      return;
    }
    addTearDown(db.close);

    final temp = await Directory.systemTemp.createTemp('school_lite_dl_fail');
    addTearDown(() => temp.delete(recursive: true));

    final client = DioClient();
    addTearDown(client.close);

    const module = CourseModule(
      id: 'acc:404',
      accountId: 'acc',
      courseId: 'acc:c',
      sectionId: 'acc:s',
      moodleId: 404,
      name: 'ملف مفقود',
      modType: 'resource',
      intro: '',
      fileUrl: 'http://127.0.0.1:1/missing.pdf',
      filename: 'missing.pdf',
      orderIndex: 0,
      available: true,
      isDownloaded: false,
    );
    await db.into(db.courseModules).insert(module);

    final service = FileDownloadService(
      dio: client.dio,
      db: db,
      documentsDir: () async => temp,
    );

    await expectLater(
      service.downloadModule(accountId: 'acc', module: module),
      throwsA(isA<DioException>()),
    );

    final record = await DownloadedFilesDao(db).byId(module.id);
    expect(record!.status, 'failed');
    final updated = await (db.select(db.courseModules)
          ..where((t) => t.id.equals(module.id)))
        .getSingle();
    expect(updated.isDownloaded, isFalse);
  });
}
