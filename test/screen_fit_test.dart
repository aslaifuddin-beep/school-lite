import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/features/accounts/presentation/quick_profile_switcher.dart';

import 'helpers/test_helpers.dart';

/// اختبار ملاءمة الواجهة العربية على أحجام شاشات مختلفة
/// (320/360/412 بكسل — أصغر شاشات وأجهزة شائعة).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <Size>[
    Size(320, 640),
    Size(360, 640),
    Size(412, 915),
  ];

  for (final size in sizes) {
    testWidgets('لوحة التحكم تناسب عرض ${size.width}px دون أخطاء',
        (tester) async {
      tester.view.physicalSize = Size(size.width, size.height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = await createContainer();
      await addDemoAccount(container, name: 'أحمد محمد العلي', username: 'ahmad');
      await addDemoAccount(container, name: 'سارة أحمد', username: 'sara');

      await tester.pumpWidget(appWithContainer(container));
      await tester.pumpAndSettle();

      // نص عربي رئيسي ظاهر.
      expect(find.textContaining(AppStrings.welcomeBack), findsWidgets);
      // الشريط السريع يعرض حساباتيْن (الحرفان الأولان من الاسم).
      expect(find.text('أع'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(QuickProfileSwitcher),
          matching: find.text('سأ'),
        ),
        findsOneWidget,
      );
      // لا أخطاء overflow أو تجاوز نصوص.
      expect(tester.takeException(), isNull);

      // التنقل للتبويبات الأخرى والتحقق من عدم ظهور أخطاء.
      for (final label in [
        AppStrings.navCourses,
        AppStrings.navAssignments,
        AppStrings.navNotifications,
        AppStrings.navSettings,
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('شاشة تسجيل الدخول تناسب أضيق شاشة (320px)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await createContainer();
    await tester.pumpWidget(appWithContainer(container));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.signIn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
