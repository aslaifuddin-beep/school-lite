import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_lite/app.dart';
import 'package:school_lite/core/security/local_auth_service.dart';
import 'package:school_lite/core/security/secure_token_store.dart';
import 'package:school_lite/core/security/security_providers.dart';
import 'package:school_lite/core/storage/prefs_provider.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';

/// مخزن توكنات وهمي للاختبارات (بدون منصة أصلية).
class FakeSecureTokenStore implements SecureTokenStore {
  final Map<String, String> _tokens = {};

  int get tokenCount => _tokens.length;
  String? tokenFor(String accountId) => _tokens[accountId];

  @override
  Future<void> write(String accountId, String token) async {
    _tokens[accountId] = token;
  }

  @override
  Future<String?> read(String accountId) async => _tokens[accountId];

  @override
  Future<void> delete(String accountId) async {
    _tokens.remove(accountId);
  }

  @override
  Future<void> deleteAll() async {
    _tokens.clear();
  }
}

/// خدمة بيومترية وهمية بنتيجة ثابتة.
class FakeLocalAuthService implements LocalAuthService {
  FakeLocalAuthService({this.available = false, this.result = false});

  final bool available;
  final bool result;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate({required String reason}) async => result;
}

/// تهيئة SharedPreferences وهمية بقيم محددة.
Future<SharedPreferences> mockPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// تجاوزات مشتركة لكل الاختبارات (عزل كامل عن المنصة الأصلية).
List<Override> baseOverrides(SharedPreferences prefs) => [
      sharedPrefsProvider.overrideWithValue(prefs),
      secureTokenStoreProvider.overrideWithValue(FakeSecureTokenStore()),
      localAuthServiceProvider.overrideWithValue(FakeLocalAuthService()),
    ];

/// حاوية اختبار جاهزة مع تنظيف تلقائي.
Future<ProviderContainer> createContainer({
  Map<String, Object> prefsValues = const {},
}) async {
  final prefs = await mockPrefs(prefsValues);
  final container = ProviderContainer(overrides: baseOverrides(prefs));
  addTearDown(container.dispose);
  return container;
}

/// إضافة حساب تجريبي سريع داخل الاختبارات.
Future<void> addDemoAccount(
  ProviderContainer container, {
  required String name,
  String username = 'user',
}) {
  return container.read(accountsProvider.notifier).add(
        serverUrl: 'https://demo.moodle.net',
        username: username,
        displayName: name,
        token: 'token-$username',
        isDemo: true,
      );
}

/// تغليف التطبيق بحاوية غير متحكَّم بها (للشاشات).
Widget appWithContainer(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: const SchoolApp(),
    );
