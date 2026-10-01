import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مزوّد الإعدادات الخفيفة (يُحقن في main.dart).
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('يجب حقن SharedPreferences في ProviderScope'),
);
