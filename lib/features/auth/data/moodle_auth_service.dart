import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/url_utils.dart';

/// نتيجة تسجيل دخول ناجح إلى خادم Moodle.
class MoodleAuthResult {
  const MoodleAuthResult({
    required this.token,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.siteName,
  });

  final String token;
  final int userId;
  final String fullName;
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
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                responseType: ResponseType.plain,
                headers: const {
                  'User-Agent': 'school_lite/1.0 (Moodle Mobile Client)',
                },
              ),
            );

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
    final base = UrlUtils.normalizeServerUrl(serverUrl);

    // 1) الحصول على التوكن من خدمة Moodle للتطبيقات المحمولة.
    final token = await _fetchToken(base, username, password);

    // 2) جلب بيانات الموقع/الطالب للتحقق وعرض الاسم.
    return _fetchSiteInfo(base, token);
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
    }
    throw const AuthException(AppStrings.invalidCredentials);
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
      throw AuthException(_messageOf(e));
    }
  }

  Future<dynamic> _getJson(String url, Map<String, dynamic> query) async {
    try {
      final response = await _dio.get<dynamic>(url, queryParameters: query);
      return _decode(response.data);
    } on DioException catch (e) {
      throw AuthException(_messageOf(e));
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

  static String _messageOf(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return AppStrings.networkError;
      case DioExceptionType.badResponse:
        return AppStrings.serviceDisabled;
      default:
        return AppStrings.networkError;
    }
  }
}
