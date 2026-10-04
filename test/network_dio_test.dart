import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/core/network/dio_client.dart';

DioException _ex({
  DioExceptionType type = DioExceptionType.unknown,
  Object? error,
  String? message,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/ws'),
    type: type,
    error: error,
    message: message,
  );
}

void main() {
  group('classifyDioError', () {
    test('شهادة مرفوضة (badCertificate) ← ssl', () {
      final e = _ex(type: DioExceptionType.badCertificate);
      expect(classifyDioError(e), MoodleNetError.ssl);
    });

    test('HandshakeException كخطأ جوّي ← ssl', () {
      final e = _ex(error: HandshakeException('tls handshake failed'));
      expect(classifyDioError(e), MoodleNetError.ssl);
    });

    test('رسالة تحوي handshake/certificate ← ssl', () {
      final e = _ex(message: 'HandshakeException: Certificate verification');
      expect(classifyDioError(e), MoodleNetError.ssl);
    });

    test('مهل زمنية/انقطاع ← network', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          classifyDioError(_ex(type: type)),
          MoodleNetError.network,
          reason: 'type=$type',
        );
      }
    });

    test('استجابة 5xx ← http', () {
      final e = _ex(type: DioExceptionType.badResponse);
      expect(classifyDioError(e), MoodleNetError.http);
    });

    test('خطأ بلا صفات مميزة ← unknown', () {
      final e = _ex(message: 'boom');
      expect(classifyDioError(e), MoodleNetError.unknown);
    });
  });

  group('messageForDioError', () {
    test('رسالة SSL عربية مميزة', () {
      expect(
        messageForDioError(_ex(type: DioExceptionType.badCertificate)),
        AppStrings.sslError,
      );
    });

    test('رسالة شبكة لانقطاع الاتصال', () {
      expect(
        messageForDioError(_ex(type: DioExceptionType.connectionTimeout)),
        AppStrings.networkError,
      );
    });

    test('رسالة خادم لخطأ HTTP', () {
      expect(
        messageForDioError(_ex(type: DioExceptionType.badResponse)),
        AppStrings.httpError,
      );
    });
  });

  group('isNetworkError', () {
    test('SSL ليس انقطاع شبكة', () {
      expect(
        isNetworkError(_ex(type: DioExceptionType.badCertificate)),
        isFalse,
      );
      expect(
        isNetworkError(_ex(error: HandshakeException('x'))),
        isFalse,
      );
    });

    test('مهل زمني شبكة صحيح', () {
      expect(
        isNetworkError(_ex(type: DioExceptionType.connectionTimeout)),
        isTrue,
      );
      expect(
        isNetworkError(_ex(type: DioExceptionType.connectionError)),
        isTrue,
      );
    });

    test('غير Dio ← ليس خطأ شبكة', () {
      expect(isNetworkError(StateError('x')), isFalse);
    });
  });
}
