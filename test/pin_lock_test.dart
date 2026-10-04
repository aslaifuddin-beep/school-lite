import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/core/security/pin_store.dart';
import 'package:school_lite/core/security/security_providers.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';
import 'package:school_lite/features/auth/presentation/lock_screen.dart';

import 'helpers/test_helpers.dart';

/// اختبارات القفل ورمز PIN (تخزين محلي مُجزَّأ + شاشة القفل).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PinStore: التعيين والتحقق الخاطئ والصحيح والإزالة', () async {
    final prefs = await mockPrefs();
    final store = PinStore(prefs);

    expect(store.isSet, isFalse);

    await store.set('1234');
    expect(store.isSet, isTrue);
    expect(store.verify('1234'), isTrue);
    expect(store.verify('9999'), isFalse);

    // الرمز المحفوظ مُجزَّأ وليس نصاً صريحاً.
    expect(prefs.getString('pin_hash_v1'), isNot(equals('1234')));
    expect(prefs.getString('pin_hash_v1'), hasLength(64));

    await store.clear();
    expect(store.isSet, isFalse);
  });

  testWidgets('القفل يظهر عند وجود رمز PIN والفتح به', (tester) async {
    // «الجيل الأول»: إنشاء حساب وتعيين رمز على نفس البيانات.
    final prefs = await mockPrefs();
    final seed = ProviderContainer(overrides: baseOverrides(prefs));
    await seed.read(accountsProvider.notifier).add(
          serverUrl: 'https://demo.moodle.net',
          username: 'ahmad',
          displayName: 'أحمد علي',
          token: 'token-ahmad',
          isDemo: true,
        );
    await seed.read(appLockProvider.notifier).setPin('1234');
    seed.dispose();

    // «إعادة تشغيل التطبيق» بحاوية جديدة فوق نفس البيانات.
    final container = ProviderContainer(overrides: baseOverrides(prefs));
    addTearDown(container.dispose);

    await tester.pumpWidget(appWithContainer(container));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text(AppStrings.lockTitle), findsOneWidget);

    // إدخال رمز خاطئ.
    for (final d in ['9', '9', '9', '9']) {
      await tester.tap(find.text(d));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.wrongPin), findsOneWidget);

    // إدخال الرمز الصحيح ← فتح الهيكل الرئيسي.
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsNothing);
    expect(find.textContaining(AppStrings.welcomeBack), findsWidgets);
    expect(tester.takeException(), isNull);
    await unmountTree(tester);
  });
}
