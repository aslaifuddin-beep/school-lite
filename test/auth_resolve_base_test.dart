import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/features/auth/data/moodle_auth_service.dart';

/// خادم HTTP محلي يحاكي توجيهات Moodle الحقيقية:
///   /  ⇒ 302 → /moodle/
Future<HttpServer> _serve({
  required int Function(HttpRequest req) handler,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final status = handler(req);
    if (status != 200) {
      req.response.statusCode = status;
    }
    await req.response.close();
  });
  addTearDown(() => server.close(force: true));
  return server;
}

void main() {
  group('MoodleAuthService.resolveBaseUrl', () {
    test('يتبع 302 حتى مجلد الفرعي /moodle', () async {
      final server = await _serve(handler: (req) {
        if (req.uri.path == '/') {
          req.response.headers
              .set(HttpHeaders.locationHeader, '/moodle/');
          return 302;
        }
        return 200;
      });
      final base = 'http://127.0.0.1:${server.port}';

      final service = MoodleAuthService();
      final resolved = await service.resolveBaseUrl(base);

      expect(resolved, '$base/moodle');
    });

    test('يحوّل مسار صفحة الدخول إلى الأساس', () async {
      final server = await _serve(handler: (req) {
        if (req.uri.path == '/') {
          req.response.headers
              .set(HttpHeaders.locationHeader, '/moodle/login/index.php');
          return 302;
        }
        return 200;
      });
      final base = 'http://127.0.0.1:${server.port}';

      final resolved = await MoodleAuthService().resolveBaseUrl(base);

      expect(resolved, '$base/moodle');
    });

    test('بلا توجيهات ← الأساس جذر بدون مسار', () async {
      final server = await _serve(handler: (_) => 200);
      final base = 'http://127.0.0.1:${server.port}';

      final resolved = await MoodleAuthService().resolveBaseUrl(base);

      expect(resolved, base);
    });

    test('خادم مُتعذر ← يُرجع المُطبَّع دون استثناء', () async {
      final resolved =
          await MoodleAuthService().resolveBaseUrl('http://127.0.0.1:1');
      expect(resolved, 'http://127.0.0.1:1');
    });

    test('دخل بدون مخطط يُطبَّع إلى https ثم يبقى كما هو عند الفشل',
        () async {
      final resolved =
          await MoodleAuthService().resolveBaseUrl('127.0.0.1:1');
      expect(resolved, 'https://127.0.0.1:1');
    });
  });
}
