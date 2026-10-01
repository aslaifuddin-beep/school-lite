import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/prefs_provider.dart';
import 'features/sync/application/background_sync.dart';

/// نقطة انطلاق التطبيق.
///
/// تهيئة سريعة (أقل من ثانية): تحميل الإعدادات الخفيفة فقط، وتأجيل أي
/// عمل ثقيل (قاعدة البيانات، الشبكة) إلى ما بعد أول إطار رسم.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const SchoolApp(),
    ),
  );

  // مهمة المزامنة الخلفية (محميّة بالكامل — فشلها لا يؤثر في التطبيق).
  await initBackgroundSync();
}
