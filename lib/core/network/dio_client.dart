import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// عميل Dio الموحّد للتطبيق: مهل زمنية + كاش HTTP للطلبات (GET).
class DioClient {
  DioClient()
      : dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            responseType: ResponseType.plain,
            headers: const {
              'User-Agent': 'school_lite/1.0 (Moodle Mobile Client)',
            },
          ),
        ) {
    // كاش على مستوى HTTP (يُستخدم للتنزيلات وطلبات GET) — كاش البيانات
    // الفعلي للمحتوى التعليمي يتم في Drift أصلاً.
    dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(),
          policy: CachePolicy.request,
          maxStale: const Duration(hours: 6),
        ),
      ),
    );
  }

  final Dio dio;

  Future<void> close() async {
    dio.close(force: true);
  }
}

/// هل هذا خطأ شبكة (انقطع الاتصال) أم خطأ من الخادم؟
bool isNetworkError(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    default:
      return false;
  }
}

/// مزوّد عميل Dio (يُغلق تلقائياً عند التخلص).
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();
  ref.onDispose(client.close);
  return client;
});

/// يقرأ ملفاً من القرص إلى FormData (للرفع).
MultipartFile fileFromPath(String path) =>
    MultipartFile.fromFileSync(path, filename: p.basename(path));
