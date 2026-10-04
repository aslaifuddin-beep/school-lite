import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/url_utils.dart';

/// نتيجة تسجيل دخول ناجح إلى خادم Moodle.
class MoodleAuthResult {
  const MoodleAuthResult({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.baseUrl,
    this.avatarUrl,
    this.siteName,
  });

  final String token;
  final int userId;
  final String fullName;

  /// أساس الرابط المُكتشف بعد متابعة التوجيهات (مثل https://host/moodle).
  /// يُحفظ في الحساب كي تعمل المزامنة على المسار الصحيح مباشرة.
  final String baseUrl;
  final String? avatarUrl;
  final String? siteName;
}

/// خطأ مصادقة — رسالته جاهزة للعرض بالعربية.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// خدمة المصادقة المباشرة مع Moodle عبر Web Services (بدون WebView).
///
/// الخطوة 1: تسجيل الدخول عبر login/token.php ثم جلب هوية الموقع.
/// الخطوة 2: تُضاف بقية wsfunction فوق نفس DioClient.
class MoodleAuthService {
  MoodleAuthService({Dio? dio})
      : _dio = dio ??
            (() {
              final d = Dio(
                BaseOptions(
                  connectTimeout: const Duration(seconds: 15),
                  receiveTimeout: const Duration(seconds: 15),
                  sendTimeout: const Duration(seconds: 15),
                  responseType: ResponseType.plain,
                ),
              );
              // عميل داخلي (غير مُحقن من الخارج) يُضبط بنفس قواعد DioClient:
              // تجاوز الشهادة + متابعة التوجيهات + User-Agent الحقيقي.
              configureMoodleDio(d);
              return d;
            })();

  final Dio _dio;

  /// تسجيل الدخول: يجلب توكن الخدمة ثم هوية المستخدم.
  Future<MoodleAuthResult> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    if (!UrlUtils.isValidServerUrl(serverUrl)) {
      throw const AuthException(AppStrings.invalidServerUrl);
    }

    // 1) اكتشاف الأساس الحقيقي (مجلد Moodle الفرعي مثل /moodle).
    final base = await resolveBaseUrl(serverUrl);

    // 2) الحصول على التوكن من خدمة Moodle للتطبيقات المحمولة.
    final token = await _fetchToken(base, username, password);

    // 3) جلب بيانات الموقع/الطالب للتحقق وعرض الاسم.
    return _fetchSiteInfo(base, token);
  }

  /// يكتشف المسار الفعلي لمجلد Moodle عبر متابعة توجيهات الرابط الذي
  /// أدخله المستخدم. مكشوف للاختبارات (يُستدعى من login بشكل طبيعي).
  ///
  /// مثال UNRWA: https://moodle.unrwa.org → 302 → /moodle/
  ///             ⇒ الأساس = https://moodle.unrwa.org/moodle
  ///
  /// اقتران المخطط: إن كان المُدخل والمُخرج http معاً نبقي http
  /// (خوادم داخلية بلا TLS)، وإلا نفرض https — خادم UNRWA يوجّه إلى
  /// http بينما الشهادة السليمة تعمل عبر https (HSTS غير مُطبَّق في dart:io).
  ///
  /// عند أي فشل يُرجع الرابط المُطبَّع كما هو (الدخول يعطي الخطأ الأدق).
  Future<String> resolveBaseUrl(String raw) async {
    final start = UrlUtils.normalizeServerUrl(raw);
    final parsed = Uri.tryParse(start);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return start;
    }

    var current = parsed;
    try {
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              return true;
            }
        ..followRedirects = false
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        for (var hop = 0; hop <= 5; hop++) {
          final req = await client.getUrl(current);
          final resp = await req.close();
          await resp.drain<void>();
          if (!resp.isRedirect) break;
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          if (loc == null || loc.isEmpty) break;
          current = current.resolve(loc);
        }
      } finally {
        client.close(force: true);
      }

      final path = _baseFromPath(current.path);
      final scheme =
          current.scheme == 'http' && parsed.scheme == 'http' ? 'http' : 'https';
      final resolved = Uri(
        scheme: scheme,
        host: current.host,
        port: current.hasPort ? current.port : null,
        path: path,
      ).toString();
      return resolved;
    } catch (_) {
      return start;
    }
  }

  /// يحوّل مسار الصفحة النهائية إلى أساس المجلد:
  ///   /moodle/ ⇒ /moodle ، /login/index.php ⇒ '' ، /moodle/login ⇒ /moodle
  static String _baseFromPath(String rawPath) {
    var path = rawPath;
    if (path.endsWith('.php')) {
      final i = path.lastIndexOf('/');
      path = i <= 0 ? '/' : path.substring(0, i);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('/login')) {
      path = path.substring(0, path.length - '/login'.length);
    }
    return path;
  }

  Future<String> _fetchToken(
    String base,
    String username,
    String password,
  ) async {
    final data = await _postJson(
      '$base/login/token.php',
      {
        'username': username,
        'password': password,
        'service': 'moodle_mobile_app',
      },
    );

    if (data is Map) {
      final token = data['token'];
      if (token is String && token.isNotEmpty) return token;

      final error = (data['error'] ?? data['errorcode'] ?? '').toString();
      if (error.contains('invalidlogin') || error.contains('invaliduser')) {
        throw const AuthException(AppStrings.invalidCredentials);
      }
      if (error.contains('webservices') || error.contains('enable')) {
        throw const AuthException(AppStrings.serviceDisabled);
      }
      if (error.isNotEmpty) {
        // نعرض رسالة الخادم إن كانت مفهومة، وإلا رسالة عامة.
        throw AuthException(
          error.toLowerCase().contains('error') && error.length < 80
              ? error
              : AppStrings.invalidCredentials,
        );
      }
      throw const AuthException(AppStrings.invalidCredentials);
    }
    // استجابة ليست كائن JSON (مثل HTML من صفحة 404) — المسار لا يشير
    // إلى نقطة token.php الصحيحة.
    throw const AuthException(AppStrings.badEndpoint);
  }

  Future<MoodleAuthResult> _fetchSiteInfo(String base, String token) async {
    final data = await _getJson('$base/webservice/rest/server.php', {
      'wstoken': token,
      'wsfunction': 'core_webservice_get_site_info',
      'moodlewsrestformat': 'json',
    });

    if (data is Map && data['userid'] != null) {
      return MoodleAuthResult(
        token: token,
        userId: (data['userid'] as num).toInt(),
        fullName: (data['fullname'] ?? data['username'] ?? '').toString(),
        baseUrl: base,
        avatarUrl: data['profileimageurl'] as String?,
        siteName: data['sitename'] as String?,
      );
    }
    throw const AuthException(AppStrings.serviceDisabled);
  }

  // -------------------------------------------------------------------------
  // أدوات HTTP عامة (تُعاد استخدامها في الخطوة 2 لبقية الـ APIs)
  // -------------------------------------------------------------------------

  Future<dynamic> _postJson(String url, Map<String, dynamic> body) async {
    try {
      // Moodle يتوقع معاملات form-urlencoded في login/token.php وليس JSON.
      final response = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _decode(response.data);
    } on DioException catch (e) {
      throw AuthException(messageForDioError(e));
    }
  }

  Future<dynamic> _getJson(String url, Map<String, dynamic> query) async {
    try {
      final response = await _dio.get<dynamic>(url, queryParameters: query);
      return _decode(response.data);
    } on DioException catch (e) {
      throw AuthException(messageForDioError(e));
    }
  }

  /// Moodle قد يعيد JSON كنص صريح (ResponseType.plain) — نفكّه بأمان.
  static dynamic _decode(dynamic raw) {
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }
}
