import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';
import 'package:school_lite/features/accounts/presentation/quick_profile_switcher.dart';

import 'helpers/test_helpers.dart';

/// اختبار الشريط العلوي السريع للتبديل بين الحسابات.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('التبديل بضغطة واحدة من الشريط العلوي دون فقدان الحالة',
      (tester) async {
    final container = await createContainer();
    await addDemoAccount(container, name: 'أحمد علي', username: 'ahmad');
    await addDemoAccount(container, name: 'سارة علي', username: 'sara');
    final accounts = container.read(accountsProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            appBar: AppBar(title: QuickProfileSwitcher()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // الحسابان ظاهران بحرفي الاسم.
    expect(find.text('أع'), findsOneWidget);
    expect(find.text('سأ'), findsOneWidget);
    expect(container.read(activeAccountIdProvider), accounts.first.id);

    // ضغطة على الحساب الثاني ← تبديل فوري.
    await tester.tap(find.text('سأ'));
    await tester.pumpAndSettle();
    expect(container.read(activeAccountIdProvider), accounts.last.id);

    // إنهاء مدة الـ SnackBar لتفادي المؤقتات المعلقة في نهاية الاختبار.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // ضغطة على الأول ← رجوع فوري.
    await tester.tap(find.text('أع'));
    await tester.pumpAndSettle();
    expect(container.read(activeAccountIdProvider), accounts.first.id);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('الشريط مخفي عند غياب الحسابات', (tester) async {
    final container = await createContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text(AppStrings.appName),
              actions: const [QuickProfileSwitcher()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(accountsProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
