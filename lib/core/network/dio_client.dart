import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_strings.dart';

/// فئة خطأ الشبكة بعد التدقيق الدقيق (لعرض رسالة صحيحة للمستخدم).
enum MoodleNetError {
  /// مصافحة/شهادة SSL فشلت (ليست انقطاعاً للإنترنت).
  ssl,

  /// انقطاع اتصال أو مهل زمنية (لا يوجد إنترنت/الخادم بعيد).
  network,

  /// استجابة HTTP غير متوقعة (5xx/4xx غير مُعالَج).
  http,

  /// غير معروف.
  unknown,
}

/// يصنّف استثناء Dio إلى فئة دقيقة: SSL ≠ شبكة ≠ خطأ خادم.
///
/// أخطى المصافحة (HandshakeException/CertificateException) تظهر أحياناً
/// مغلّفة ضمن connectionError — نفحصها أولاً كي لا توهم المستخدم بأن
/// الإنترنت منقطع بينما المشكلة في الشهادة.
MoodleNetError classifyDioError(DioException e) {
  final err = e.error;
  if (err is HandshakeException || err is CertificateException) {
    return MoodleNetError.ssl;
  }
  if (err is TlsException) return MoodleNetError.ssl;

  switch (e.type) {
    case DioExceptionType.badCertificate:
      return MoodleNetError.ssl;
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return MoodleNetError.network;
    case DioExceptionType.badResponse:
      return MoodleNetError.http;
    default:
      break;
  }
  // التقاط رسائل المصافحة المُرمَّزة كنص من بعض الأنظمة.
  final msg = (e.message ?? err?.toString() ?? '').toLowerCase();
  if (msg.contains('handshake') || msg.contains('certificate')) {
    return MoodleNetError.ssl;
  }
  return MoodleNetError.unknown;
}

/// رسالة عربية جاهزة للعرض حسب فئة الخطأ.
String messageForDioError(DioException e) {
  switch (classifyDioError(e)) {
    case MoodleNetError.ssl:
      return AppStrings.sslError;
    case MoodleNetError.network:
    case MoodleNetError.unknown:
      return AppStrings.networkError;
    case MoodleNetError.http:
      return AppStrings.httpError;
  }
}

/// يضبط عميل Dio للعمل مع خوادم Moodle المؤسسية:
/// • تجاوز التحقق من الشهادة (شهادات مُثبَّتة ذاتياً/داخلية) — كما طُلب.
/// • متابعة التوجيهات 301/302 حتى 5 مرات.
/// • User-Agent متصفّح حقيقي كي لا يحجبه WAF الخادم.
///
/// بدون Content-Type عام: رفع FormData يحتاج multipart تلقائياً،
/// وكل نداءات Moodle تضبط form-urlencoded per-request أصلاً.
void configureMoodleDio(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      return HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return true;
            }
        ..followRedirects = true
        ..maxRedirects = 5;
    },
  );
  dio.options.headers.addAll(const {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  });
}

/// عميل Dio الموحّد للتطبيق: مهل زمنية + كاش HTTP للطلبات (GET).
class DioClient {
  DioClient()
      : dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            responseType: ResponseType.plain,
          ),
        ) {
    configureMoodleDio(dio);

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

/// هل هذا خطأ شبكة (انقطع الاتصال) أم خطأ آخر؟
///
/// أخطاء SSL ليست انقطاعاً: المحرك يجب أن يعرض رسالة الخطأ لا أن
/// يتوقف صامتاً بانتظار عودة "الشبكة" التي لم تنقطع.
bool isNetworkError(Object error) {
  if (error is! DioException) return false;
  if (classifyDioError(error) == MoodleNetError.ssl) return false;
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
