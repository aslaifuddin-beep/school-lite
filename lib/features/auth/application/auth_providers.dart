import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/moodle_auth_service.dart';

/// خدمة المصادقة (قابلة للاستبدال في الاختبارات).
///
/// تستخدم نفس عميل Dio الموحّد (DioClient) — بنفس تجاوز الشهادة
/// وUser-Agent ومتابعة التوجيهات المُطبَّقة على بقية نداءات Moodle.
final moodleAuthServiceProvider = Provider<MoodleAuthService>(
  (ref) => MoodleAuthService(dio: ref.watch(dioClientProvider).dio),
);
