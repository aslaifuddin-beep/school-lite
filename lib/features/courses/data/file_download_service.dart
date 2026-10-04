import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/content_dao.dart';
import '../../../core/db/daos/extras_daos.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/dio_client.dart';

/// مزوّد خدمة تنزيل ملفات المقررات (ملفات Moodle pluginfile).
final fileDownloadServiceProvider = Provider<FileDownloadService>((ref) {
  return FileDownloadService(
    dio: ref.watch(dioClientProvider).dio,
    db: ref.watch(databaseProvider),
  );
});

/// خدمة تنزيل ملف وحدة إلى مجلد التطبيق للعرض دون إنترنت:
/// 1) تسجيل الملف في `downloaded_files` بحالة downloading.
/// 2) تنزيل عبر Dio (مع تجاوز الشهادة وتوجيهات كما في باقي التطبيق).
/// 3) تعليم الوحدة `isDownloaded + localPath` وإتمام السجل.
/// عند الفشل: status=failed ويُعاد رمي الخطأ لعرضه في الواجهة.
class FileDownloadService {
  FileDownloadService({
    required this.dio,
    required this.db,
    Future<Directory> Function()? documentsDir,
  })  : _documentsDir = documentsDir,
        _files = DownloadedFilesDao(db),
        _content = ContentDao(db);

  final Dio dio;
  final AppDatabase db;
  final Future<Directory> Function()? _documentsDir;
  final DownloadedFilesDao _files;
  final ContentDao _content;

  /// مسار التنزيلات الخاص بحساب (يُنشأ عند أول استخدام).
  Future<Directory> downloadsDir(String accountId) async {
    final docs = _documentsDir != null
        ? await _documentsDir()
        : await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'downloads', accountId));
    await dir.create(recursive: true);
    return dir;
  }

  /// تنزيل ملف وحدة وتسجيله محلياً — يعيد المسار المحلي.
  Future<String> downloadModule({
    required String accountId,
    required CourseModule module,
    String? baseUrl,
  }) async {
    var url = (module.fileUrl ?? '').trim();
    if (url.isEmpty) {
      throw StateError('لا يوجد رابط للملف');
    }
    // روابط pluginfile أحياناً مسبوقة بشرطة مائلة → نلحقها بقاعدة الحساب.
    if (url.startsWith('/') && baseUrl != null && baseUrl.isNotEmpty) {
      url = '$baseUrl$url';
    }

    final dir = await downloadsDir(accountId);
    final rawName = (module.filename ?? '').trim();
    final filename = rawName.isEmpty ? 'module_${module.moodleId}' : rawName;
    final dest = p.join(dir.path, '${module.moodleId}_$filename');

    await _files.upsert(
      accountId: accountId,
      id: module.id,
      sourceUrl: url,
      localPath: dest,
      filename: filename,
      fileSize: module.fileSize,
      status: 'downloading',
    );

    try {
      await dio.download(url, dest, deleteOnError: true);
      await _files.setStatus(module.id, 'downloaded');
      await _content.markModuleDownloaded(
        accountId: accountId,
        moduleId: module.id,
        localPath: dest,
        downloaded: true,
      );
      return dest;
    } catch (_) {
      await _files.setStatus(module.id, 'failed');
      rethrow;
    }
  }

  /// إزالة ملف محفوظ (حذف من القرص + إلغاء تعليم الوحدة).
  Future<void> removeDownload({
    required String accountId,
    required CourseModule module,
  }) async {
    final record = await _files.byId(module.id);
    final path = (record != null && record.localPath.isNotEmpty)
        ? record.localPath
        : (module.localPath ?? '');
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _files.setStatus(module.id, 'removed');
    await _content.markModuleDownloaded(
      accountId: accountId,
      moduleId: module.id,
      localPath: '',
      downloaded: false,
    );
  }
}
