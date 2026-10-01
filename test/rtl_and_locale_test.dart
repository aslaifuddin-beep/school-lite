import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/features/auth/presentation/login_screen.dart';

import 'helpers/test_helpers.dart';

/// اختبارات اللغة العربية والاتجاه من اليمين إلى اليسار.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('التطبيق يبدأ بالعربية واتجاه RTL مع شاشة دخول عربية',
      (tester) async {
    final container = await createContainer();
    await tester.pumpWidget(appWithContainer(container));
    await tester.pumpAndSettle();

    // لا حسابات ← شاشة تسجيل الدخول.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.serverUrl), findsOneWidget);
    expect(find.text(AppStrings.demoMode), findsOneWidget);

    // الاتجاه واللغة.
    final context = tester.element(find.byType(LoginScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('ar'));

    // لا أخطاء تجاوز/ترتيب في النصوص العربية.
    expect(tester.takeException(), isNull);
  });

  testWidgets('إضافة حساب تجريبي ينقل إلى الهيكل الرئيسي العربي',
      (tester) async {
    // زر «وضع العرض» أسفل محتوى الشاشة — نضمن ظهوره على ارتفاع كافٍ.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await createContainer();
    await tester.pumpWidget(appWithContainer(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.demoMode));
    await tester.pumpAndSettle();

    // التبويبات العربية ظاهرة.
    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navCourses), findsOneWidget);
    expect(find.text(AppStrings.navAssignments), findsOneWidget);
    expect(find.text(AppStrings.navNotifications), findsOneWidget);
    expect(find.text(AppStrings.navSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
