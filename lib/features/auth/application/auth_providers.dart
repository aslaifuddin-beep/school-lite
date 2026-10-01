import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moodle_auth_service.dart';

/// خدمة المصادقة (قابلة للاستبدال في الاختبارات).
final moodleAuthServiceProvider = Provider<MoodleAuthService>(
  (ref) => MoodleAuthService(),
);
