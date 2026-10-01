import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/security/security_providers.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';

import 'helpers/test_helpers.dart';

/// اختبارات وحدة لنظام الحسابات المتعددة والتبديل السريع.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('إضافة حتى 10 حسابات ثم رفض الحساب الحادي عشر', () async {
    final container = await createContainer();

    for (var i = 1; i <= 10; i++) {
      await addDemoAccount(
        container,
        name: 'طالب $i',
        username: 'student$i',
      );
    }

    final accounts = container.read(accountsProvider);
    expect(accounts, hasLength(10));
    expect(container.read(activeAccountIdProvider), accounts.last.id);

    await expectLater(
      addDemoAccount(container, name: 'طالب 11', username: 'student11'),
      throwsA(isA<AccountsLimitException>()),
    );
    expect(container.read(accountsProvider), hasLength(10));
  });

  test('حفظ التوكن آمناً لكل حساب ومنفصل عنه', () async {
    final container = await createContainer();
    await addDemoAccount(container, name: 'أحمد', username: 'ahmad');
    await addDemoAccount(container, name: 'سارة', username: 'sara');

    final store = container.read(secureTokenStoreProvider);
    expect(store, isA<FakeSecureTokenStore>());

    final fake = store as FakeSecureTokenStore;
    expect(fake.tokenCount, 2);
    final accounts = container.read(accountsProvider);
    expect(fake.tokenFor(accounts.first.id), 'token-ahmad');
    expect(fake.tokenFor(accounts.last.id), 'token-sara');
  });

  test('التبديل بين الحسابات فوري ويحفظ التفضيل', () async {
    final container = await createContainer();
    await addDemoAccount(container, name: 'أحمد', username: 'ahmad');
    await addDemoAccount(container, name: 'سارة', username: 'sara');
    final accounts = container.read(accountsProvider);

    await container
        .read(activeAccountIdProvider.notifier)
        .select(accounts.last.id);
    expect(container.read(activeAccountIdProvider), accounts.last.id);
    expect(container.read(activeAccountProvider)?.displayName, 'سارة');

    await container
        .read(activeAccountIdProvider.notifier)
        .select(accounts.first.id);
    expect(container.read(activeAccountIdProvider), accounts.first.id);
  });

  test('حذف الحساب النشط يحوّل النشاط لأول حساب متبقٍ', () async {
    final container = await createContainer();
    await addDemoAccount(container, name: 'أحمد', username: 'ahmad');
    await addDemoAccount(container, name: 'سارة', username: 'sara');
    final accounts = container.read(accountsProvider);

    await container
        .read(activeAccountIdProvider.notifier)
        .select(accounts.last.id);

    await container.read(accountsProvider.notifier).remove(accounts.last.id);

    final remaining = container.read(accountsProvider);
    expect(remaining, hasLength(1));
    expect(container.read(activeAccountIdProvider), remaining.single.id);

    // حذف آخر حساب ← لا حساب نشط + حُذف التوكن.
    await container.read(accountsProvider.notifier).remove(remaining.single.id);
    expect(container.read(accountsProvider), isEmpty);
    expect(container.read(activeAccountIdProvider), isNull);
    final fake = container.read(secureTokenStoreProvider) as FakeSecureTokenStore;
    expect(fake.tokenCount, 0);
  });

  test('تعيين رمز PIN يفعّل القفل عند التشغيل التالي', () async {
    final container = await createContainer();
    await addDemoAccount(container, name: 'أحمد', username: 'ahmad');

    expect(container.read(appLockProvider).isPinSet, isFalse);

    await container.read(appLockProvider.notifier).setPin('1234');
    final state = container.read(appLockProvider);
    expect(state.isPinSet, isTrue);
    // تعيين الرمز لا يقفل الجلسة الحالية فوراً.
    expect(state.isLocked, isFalse);

    await container.read(appLockProvider.notifier).clearPin();
    expect(container.read(appLockProvider).isPinSet, isFalse);
  });
}
